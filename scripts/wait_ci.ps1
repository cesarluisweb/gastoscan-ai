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
#   - Espera internamente (Start-Sleep) hasta que todos los runs del commit
#     concluyan o venza el tope.
#   - Soporta flujos desacoplados: si el commit solo disparo el workflow ligero
#     `deploy_web.yml` (~45 s), ajusta el intervalo a 30 s automaticamente.
#   - Si falla, imprime SOLO los steps fallidos y la cola de test_results.txt,
#     nunca el log completo del job (que ademas devuelve HTTP 403 en repo privado).
#
# Presupuesto de API (importante):
#   Sin token, GitHub limita a 60 peticiones/hora por IP. Por eso el intervalo por
#   defecto para compilacion Android es de 180 s (y 30 s para web corta). Con
#   GITHUB_TOKEN en el entorno (5.000 peticiones/hora) se puede bajar con
#   -IntervalSeconds 60. Ante HTTP 403 el script espera a que se restablezca la
#   cuota en lugar de fallar en silencio.
#
# Codigos de salida:
#   0 = CI en verde         1 = CI fallo         2 = repo inaccesible (401/404)
#   3 = tope de tiempo       4 = el push no disparo CI (paths-ignore?)
# NOTA: el harness de ejecucion en segundo plano puede normalizar cualquier
# codigo distinto de 0 a 1. La linea impresa es la senal autoritativa, no el
# codigo de salida.
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
    [int]$WebIntervalSeconds = 30,
    [int]$TestLogTailLines = 40
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$CustomInterval = $PSBoundParameters.ContainsKey('IntervalSeconds')

function Get-ApiHeaders {
    $headers = @{
        'Accept'     = 'application/vnd.github+json'
        'User-Agent' = 'rindemas-wait-ci'
    }
    $token = $env:GITHUB_TOKEN
    if (-not $token) {
        $token = [System.Environment]::GetEnvironmentVariable('GITHUB_TOKEN', 'User')
    }
    if ($token -and $token.Trim().Length -gt 0) {
        $headers['Authorization'] = 'Bearer ' + $token.Trim()
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

# Breve pausa inicial para permitir que GitHub Actions registre los workflows del push
Start-Sleep -Seconds 6

# 2. Localizar TODOS los runs del commit (puede ser deploy_web.yml, build_apk.yml o ambos)
$matchedRuns = @()
while ((Get-Date) -lt $discoveryDeadline -and $matchedRuns.Count -eq 0) {
    $runs = Invoke-Api ($apiBase + '/actions/runs?branch=' + $Branch + '&per_page=15')
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
        Start-Sleep -Seconds (Get-SleepSeconds -Seconds 20 -Deadline $discoveryDeadline)
        continue
    }

    if ($Sha) {
        $matchedRuns = @($runs.workflow_runs | Where-Object { $_.head_sha -eq $Sha -or $_.head_sha -like ($Sha + '*') })
    }
    if ($matchedRuns.Count -eq 0) {
        Start-Sleep -Seconds (Get-SleepSeconds -Seconds 20 -Deadline $discoveryDeadline)
        continue
    }
}

if ($matchedRuns.Count -eq 0) {
    'CI: SIN RUN | ' + $shaShort + ' no disparo compilacion en ' + $DiscoveryMinutes + ' min (revisa paths-ignore)'
    exit 4
}

# Determinar si hay compilacion pesada de Android o solo despliegue web ligero
$hasAndroidBuild = $false
foreach ($r in $matchedRuns) {
    if ($r.path -like '*build_apk*' -or $r.name -like '*APK*') {
        $hasAndroidBuild = $true
    }
}
$pollSeconds = $IntervalSeconds
if (-not $hasAndroidBuild -and -not $CustomInterval) {
    $pollSeconds = $WebIntervalSeconds
}

# 3. Esperar a que TODOS los runs del commit concluyan
$runStates = @{}
foreach ($r in $matchedRuns) {
    $runStates[[int64]$r.id] = $r
}

while ((Get-Date) -lt $deadline) {
    $pendingIds = @($runStates.Keys | Where-Object { $runStates[$_].status -ne 'completed' })
    if ($pendingIds.Count -eq 0) {
        break
    }

    foreach ($rid in $pendingIds) {
        $updated = Invoke-Api ($apiBase + '/actions/runs/' + $rid)
        if ($null -ne $updated) {
            $runStates[$rid] = $updated
        } elseif ($script:HttpStatus -eq 403 -and $script:RateReset -gt 0) {
            $wait = [int][Math]::Max(5, ($script:RateReset - [datetimeoffset]::UtcNow.ToUnixTimeSeconds()))
            Start-Sleep -Seconds (Get-SleepSeconds -Seconds $wait -Deadline $deadline)
            break
        }
    }

    $stillPending = @($runStates.Keys | Where-Object { $runStates[$_].status -ne 'completed' })
    if ($stillPending.Count -eq 0) {
        break
    }

    Start-Sleep -Seconds (Get-SleepSeconds -Seconds $pollSeconds -Deadline $deadline)
}

# 4. Imprimir resultados y diagnosticar fallos
$anyIncomplete = $false
$anyFailed = $false
$androidFailed = $false

foreach ($rid in ($runStates.Keys | Sort-Object)) {
    $r = $runStates[$rid]
    $wfName = [string]$r.name
    $rNum = [int64]$r.run_number
    if ($r.status -ne 'completed') {
        $anyIncomplete = $true
        'CI ' + $rid + ' (' + $wfName + ') | EN CURSO | tope ' + $MaxMinutes + ' min | build ' + $rNum + ' | ' + $shaShort
    } else {
        $conc = [string]$r.conclusion
        'CI ' + $rid + ' (' + $wfName + ') | ' + $conc + ' | build ' + $rNum + ' | ' + $shaShort
        if ($conc -ne 'success') {
            $anyFailed = $true
            if ($r.path -like '*build_apk*' -or $wfName -like '*APK*') {
                $androidFailed = $true
            }
            $jobs = Invoke-Api ($apiBase + '/actions/runs/' + $rid + '/jobs')
            if ($null -ne $jobs) {
                $failed = @($jobs.jobs | ForEach-Object { $_.steps } | Where-Object { $_.conclusion -eq 'failure' })
                foreach ($s in $failed) {
                    '  step fallido: #' + $s.number + ' ' + $s.name
                }
            }
        }
    }
}

if ($anyIncomplete) {
    exit 3
}

if ($anyFailed) {
    if ($androidFailed) {
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
    }
    exit 1
}

exit 0
