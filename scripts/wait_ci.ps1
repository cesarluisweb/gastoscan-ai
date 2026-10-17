# ==============================================================================
# scripts/wait_ci.ps1
# Proceso dormido de monitoreo de GitHub Actions para Rinde Mas.
#
# Lanzar UNA SOLA VEZ en segundo plano tras cada git push:
#     powershell -ExecutionPolicy Bypass -File scripts/wait_ci.ps1
#
# Ahorro de tokens:
#   - Una invocacion, una salida. Prohibido `gh run watch` y prohibido consultar
#     el estado del CI turno tras turno desde el agente.
#   - Espera internamente (Start-Sleep) hasta que el run concluya o venza el tope.
#   - Si falla, imprime SOLO los steps fallidos y la cola de test_results.txt,
#     nunca el log completo del job (que ademas devuelve HTTP 403 en repo privado).
#
# Presupuesto de API (importante):
#   Sin token, GitHub limita a 60 peticiones/hora por IP. Por eso el intervalo por
#   defecto es de 180 s. Con GITHUB_TOKEN en el entorno (5.000 peticiones/hora)
#   se puede bajar a 60 s con -IntervalSeconds 60. Ante HTTP 403 el script espera
#   a que se restablezca la cuota en lugar de fallar en silencio.
#
# Codigos de salida:
#   0 = CI en verde         1 = CI fallo         2 = repo inaccesible (401/404)
#   3 = tope de tiempo       4 = el push no disparo CI (paths-ignore?)
#
# ASCII puro a proposito: PowerShell 5.1 lee los .ps1 sin BOM como ANSI.
# ==============================================================================

[CmdletBinding()]
param(
    [string]$Repo = 'cesarluisweb/gastoscan-ai',
    [string]$Branch = 'main',
    [string]$Sha = '',
    [int]$MaxMinutes = 25,
    [int]$DiscoveryMinutes = 5,
    [int]$IntervalSeconds = 180,
    [int]$TestLogTailLines = 40
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

function Get-ApiHeaders {
    $headers = @{
        'Accept'     = 'application/vnd.github+json'
        'User-Agent' = 'rindemas-wait-ci'
    }
    if ($env:GITHUB_TOKEN -and $env:GITHUB_TOKEN.Trim().Length -gt 0) {
        $headers['Authorization'] = 'Bearer ' + $env:GITHUB_TOKEN.Trim()
    }
    return $headers
}

# Devuelve el objeto, o $null ante error controlado.
# Deja el codigo HTTP en $script:HttpStatus y el epoch de reposicion en $script:RateReset.
function Invoke-Api {
    param([string]$Uri)
    $script:HttpStatus = 200
    $script:RateReset = 0
    try {
        return Invoke-RestMethod -Uri $Uri -Headers (Get-ApiHeaders) -Method Get
    } catch {
        $status = 0
        try { $status = [int]$_.Exception.Response.StatusCode } catch { $status = 0 }
        $script:HttpStatus = $status
        if ($status -eq 403) {
            try {
                $raw = $_.Exception.Response.Headers['X-RateLimit-Reset']
                if ($raw) { $script:RateReset = [int64]$raw }
            } catch { $script:RateReset = 0 }
        }
        return $null
    }
}

function Get-SleepSeconds {
    param([int]$Seconds, [datetime]$Deadline)
    $remaining = ($Deadline - (Get-Date)).TotalSeconds
    if ($remaining -lt $Seconds) { $Seconds = [int][Math]::Max(1, $remaining) }
    return $Seconds
}

# 1. Resolver el commit actual
if ([string]::IsNullOrWhiteSpace($Sha)) {
    try { $Sha = [string](git rev-parse HEAD) } catch { $Sha = '' }
    if ($null -ne $Sha) { $Sha = $Sha.Trim() }
}
if ($Sha.Length -ge 7) { $shaShort = $Sha.Substring(0, 7) } else { $shaShort = $Sha }

$apiBase = 'https://api.github.com/repos/' + $Repo
$startedAt = Get-Date
$discoveryDeadline = $startedAt.AddMinutes($DiscoveryMinutes)
$deadline = $startedAt.AddMinutes($MaxMinutes)

# 2. Localizar el run del commit (el run tarda unos segundos en registrarse)
$runId = [int64]0
$runNumber = 0
while ((Get-Date) -lt $discoveryDeadline -and $runId -eq 0) {
    $runs = Invoke-Api ($apiBase + '/actions/runs?branch=' + $Branch + '&per_page=10')
    if ($null -eq $runs) {
        if ($script:HttpStatus -eq 401 -or $script:HttpStatus -eq 404) {
            'CI: SIN ACCESO | HTTP ' + $script:HttpStatus + ' | repo ' + $Repo
            'Si el repositorio volvio a Privado, define GITHUB_TOKEN en el entorno (nunca en un archivo versionado).'
            exit 2
        }
        if ($script:HttpStatus -eq 403 -and $script:RateReset -gt 0) {
            $wait = [int][Math]::Max(5, ($script:RateReset - [datetimeoffset]::UtcNow.ToUnixTimeSeconds()))
            'CI: CUOTA API AGOTADA | reintento en ' + $wait + ' s (define GITHUB_TOKEN para 5.000/hora)'
            Start-Sleep -Seconds (Get-SleepSeconds -Seconds $wait -Deadline $discoveryDeadline)
            continue
        }
        Start-Sleep -Seconds (Get-SleepSeconds -Seconds $IntervalSeconds -Deadline $discoveryDeadline)
        continue
    }

    $match = $null
    if ($Sha) {
        $match = @($runs.workflow_runs) | Where-Object { $_.head_sha -eq $Sha } | Select-Object -First 1
    }
    if ($null -eq $match) {
        Start-Sleep -Seconds (Get-SleepSeconds -Seconds $IntervalSeconds -Deadline $discoveryDeadline)
        continue
    }

    $runId = [int64]$match.id
    $runNumber = [int64]$match.run_number
}

if ($runId -eq 0) {
    'CI: SIN RUN | ' + $shaShort + ' no disparo compilacion en ' + $DiscoveryMinutes + ' min (revisa paths-ignore)'
    exit 4
}

# 3. Esperar a que el run concluya
$conclusion = ''
while ((Get-Date) -lt $deadline) {
    $run = Invoke-Api ($apiBase + '/actions/runs/' + $runId)
    if ($null -ne $run) {
        if ($run.status -eq 'completed') {
            $conclusion = [string]$run.conclusion
            break
        }
        Start-Sleep -Seconds (Get-SleepSeconds -Seconds $IntervalSeconds -Deadline $deadline)
        continue
    }
    if ($script:HttpStatus -eq 403 -and $script:RateReset -gt 0) {
        $wait = [int][Math]::Max(5, ($script:RateReset - [datetimeoffset]::UtcNow.ToUnixTimeSeconds()))
        Start-Sleep -Seconds (Get-SleepSeconds -Seconds $wait -Deadline $deadline)
        continue
    }
    Start-Sleep -Seconds (Get-SleepSeconds -Seconds $IntervalSeconds -Deadline $deadline)
}

if ($conclusion -eq '') {
    'CI ' + $runId + ' | EN CURSO | tope ' + $MaxMinutes + ' min | build ' + $runNumber + ' | ' + $shaShort
    exit 3
}

'CI ' + $runId + ' | ' + $conclusion + ' | build ' + $runNumber + ' | ' + $shaShort

if ($conclusion -ne 'success') {
    # 3a. Solo los steps fallidos
    $jobs = Invoke-Api ($apiBase + '/actions/runs/' + $runId + '/jobs')
    if ($null -ne $jobs) {
        $failed = @($jobs.jobs | ForEach-Object { $_.steps } | Where-Object { $_.conclusion -eq 'failure' })
        foreach ($s in $failed) {
            '  step fallido: #' + $s.number + ' ' + $s.name
        }
    }

    # 3b. Cola del reporte remoto (el workflow lo commitea en el paso "Guardar Logs de Error")
    for ($i = 1; $i -le 3; $i++) {
        git fetch origin $Branch --quiet 2>$null
        $logRef = 'origin/' + $Branch + ':test_results.txt'
        $log = git show $logRef 2>$null
        if ($LASTEXITCODE -eq 0 -and $log) {
            '  --- test_results.txt (ultimas ' + $TestLogTailLines + ' lineas) ---'
            @($log) | Select-Object -Last $TestLogTailLines | ForEach-Object { '  ' + $_ }
            break
        }
        Start-Sleep -Seconds 10
    }
    exit 1
}

exit 0
