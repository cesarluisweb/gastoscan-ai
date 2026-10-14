# ==============================================================================
# scripts/check_rules.ps1
# Validador de reglas y habilidades de Antigravity para Rinde Mas
# Comprueba:
#   1. Tamano en bytes UTF-8 (limite estricto 24.000 bytes por archivo).
#   2. Formato y campos obligatorios de YAML frontmatter.
#   3. Triggers validos en snake_case (always_on, model_decision, glob, manual).
#   4. Presupuesto acumulado de reglas always_on / raiz (~20.000 tokens).
# ==============================================================================

[CmdletBinding()]
param(
    [string]$RootDir = (Get-Location).Path,
    [int]$HardByteLimit = 24000,
    [int]$WarnByteLimit = 20000,
    [int]$AlwaysOnTokenLimit = 20000
)

$ErrorActionPreference = "Continue"
$Script:HasErrors = $false
$Script:HasWarnings = $false

function Write-Status {
    param(
        [string]$Level, # OK, WARN, ERROR
        [string]$Message
    )
    switch ($Level) {
        "OK"    { Write-Host "  [OK]    $Message" -ForegroundColor Green }
        "WARN"  { Write-Host "  [WARN]  $Message" -ForegroundColor Yellow; $Script:HasWarnings = $true }
        "ERROR" { Write-Host "  [ERROR] $Message" -ForegroundColor Red;    $Script:HasErrors = $true }
        default { Write-Host "          $Message" }
    }
}

Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host "  Auditoria de Reglas y Habilidades Antigravity (Rinde Mas) " -ForegroundColor Cyan
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host "Directorio raiz: $RootDir"
Write-Host "Limite por archivo: $HardByteLimit bytes UTF-8 (Alerta: $WarnByteLimit bytes)"
Write-Host ""

$ValidTriggers = @("always_on", "model_decision", "glob", "manual")
$AlwaysOnTotalBytes = 0

# ------------------------------------------------------------------------------
# 1. Validar AGENTS.md raiz
# ------------------------------------------------------------------------------
Write-Host "[1/3] Verificando AGENTS.md raiz..." -ForegroundColor Cyan
$AgentsPath = Join-Path $RootDir "AGENTS.md"

if (Test-Path $AgentsPath) {
    $content = [System.IO.File]::ReadAllText($AgentsPath, [System.Text.Encoding]::UTF8)
    $utf8Bytes = [System.Text.Encoding]::UTF8.GetByteCount($content)
    $AlwaysOnTotalBytes += $utf8Bytes

    if ($utf8Bytes -gt $HardByteLimit) {
        Write-Status "ERROR" "AGENTS.md excede el limite de 24 KB ($utf8Bytes bytes UTF-8 > $HardByteLimit). Antigravity lo truncara."
    } elseif ($utf8Bytes -gt $WarnByteLimit) {
        Write-Status "WARN" "AGENTS.md se acerca al limite ($utf8Bytes bytes UTF-8 > $WarnByteLimit)."
    } else {
        Write-Status "OK" "AGENTS.md: $utf8Bytes bytes UTF-8 (dentro del limite)."
    }

    # AGENTS.md no debe llevar frontmatter
    $lines = $content -split "`r?`n"
    if ($lines.Count -gt 0 -and $lines[0].Trim() -eq "---") {
        Write-Status "WARN" "AGENTS.md raiz tiene frontmatter '---'. Los archivos raiz no lo requieren y podria ser ignorado."
    }
} else {
    Write-Status "ERROR" "No se encontro el archivo AGENTS.md en $RootDir."
}

Write-Host ""

# ------------------------------------------------------------------------------
# 2. Validar reglas modulares en .agents/rules/*.md
# ------------------------------------------------------------------------------
Write-Host "[2/3] Verificando reglas modulares en .agents/rules/..." -ForegroundColor Cyan
$RulesDir = Join-Path $RootDir ".agents\rules"

if (Test-Path $RulesDir) {
    $ruleFiles = Get-ChildItem -Path $RulesDir -Filter "*.md" | Sort-Object Name

    if ($ruleFiles.Count -eq 0) {
        Write-Status "WARN" "No se encontraron archivos .md en $RulesDir."
    }

    foreach ($file in $ruleFiles) {
        $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
        $utf8Bytes = [System.Text.Encoding]::UTF8.GetByteCount($content)

        # 1. Comprobacion de tamano en bytes UTF-8
        if ($utf8Bytes -gt $HardByteLimit) {
            Write-Status "ERROR" "$($file.Name): $utf8Bytes bytes UTF-8 > $HardByteLimit bytes. Sera truncado silenciosamente."
        } elseif ($utf8Bytes -gt $WarnByteLimit) {
            Write-Status "WARN" "$($file.Name): $utf8Bytes bytes UTF-8 > $WarnByteLimit bytes (cerca del limite)."
        } else {
            Write-Status "OK" "$($file.Name): $utf8Bytes bytes UTF-8."
        }

        # 2. Comprobacion de frontmatter
        $lines = $content -split "`r?`n"
        if ($lines.Count -lt 3 -or $lines[0].Trim() -ne "---") {
            Write-Status "ERROR" "$($file.Name): Debe iniciar con '---' en la linea 1. Sin frontmatter sera descartado en silencio."
            continue
        }

        # Buscar cierre de frontmatter
        $closingIndex = -1
        for ($i = 1; $i -lt [Math]::Min($lines.Count, 30); $i++) {
            if ($lines[$i].Trim() -eq "---") {
                $closingIndex = $i
                break
            }
        }

        if ($closingIndex -eq -1) {
            Write-Status "ERROR" "$($file.Name): No tiene cierre de frontmatter '---' en las primeras 30 lineas."
            continue
        }

        $frontmatterBlock = ($lines[1..($closingIndex - 1)]) -join "`n"

        # 3. Validar trigger
        if ($frontmatterBlock -match "(?m)^trigger:\s*(\S+)") {
            $triggerVal = $Matches[1].Trim().Trim('"').Trim("'")
            if ($ValidTriggers -notcontains $triggerVal) {
                Write-Status "ERROR" "$($file.Name): Trigger invalido '$triggerVal'. Validos: $($ValidTriggers -join ', ')."
            } else {
                # Si es always_on, suma al presupuesto
                if ($triggerVal -eq "always_on") {
                    $AlwaysOnTotalBytes += $utf8Bytes
                }
                # Si es glob, requiere campo globs/glob
                if ($triggerVal -eq "glob") {
                    if ($frontmatterBlock -notmatch "(?m)^(globs?):") {
                        Write-Status "ERROR" "$($file.Name): trigger 'glob' requiere especificar 'glob:' o 'globs:'."
                    }
                }
            }
        } else {
            Write-Status "ERROR" "$($file.Name): Falta el campo obligatorio 'trigger:' en el frontmatter."
        }

        # 4. Validar description
        if ($frontmatterBlock -notmatch "(?m)^description:") {
            Write-Status "WARN" "$($file.Name): Falta 'description:' en el frontmatter (recomendado para model_decision)."
        }
    }
} else {
    Write-Status "WARN" "No existe el directorio $RulesDir."
}

Write-Host ""

# ------------------------------------------------------------------------------
# 3. Validar habilidades en .agents/skills/*/SKILL.md
# ------------------------------------------------------------------------------
Write-Host "[3/3] Verificando habilidades en .agents/skills/..." -ForegroundColor Cyan
$SkillsDir = Join-Path $RootDir ".agents\skills"

if (Test-Path $SkillsDir) {
    $skillFolders = Get-ChildItem -Path $SkillsDir -Directory | Sort-Object Name

    foreach ($folder in $skillFolders) {
        $skillFile = Join-Path $folder.FullName "SKILL.md"
        if (-not (Test-Path $skillFile)) {
            Write-Status "ERROR" "Carpeta $($folder.Name) no contiene SKILL.md."
            continue
        }

        $content = [System.IO.File]::ReadAllText($skillFile, [System.Text.Encoding]::UTF8)
        $utf8Bytes = [System.Text.Encoding]::UTF8.GetByteCount($content)

        if ($utf8Bytes -gt $HardByteLimit) {
            Write-Status "WARN" "$($folder.Name)/SKILL.md supera 24 KB ($utf8Bytes bytes). Conviene mover detalles a references/."
        } else {
            Write-Status "OK" "$($folder.Name)/SKILL.md: $utf8Bytes bytes UTF-8."
        }

        # Validar frontmatter
        $lines = $content -split "`r?`n"
        if ($lines.Count -lt 3 -or $lines[0].Trim() -ne "---") {
            Write-Status "ERROR" "$($folder.Name)/SKILL.md no inicia con '---'."
            continue
        }

        $closingIndex = -1
        for ($i = 1; $i -lt [Math]::Min($lines.Count, 30); $i++) {
            if ($lines[$i].Trim() -eq "---") {
                $closingIndex = $i
                break
            }
        }

        if ($closingIndex -eq -1) {
            Write-Status "ERROR" "$($folder.Name)/SKILL.md no cierra el frontmatter '---'."
            continue
        }

        $frontmatterBlock = ($lines[1..($closingIndex - 1)]) -join "`n"

        if ($frontmatterBlock -notmatch "(?m)^name:") {
            Write-Status "ERROR" "$($folder.Name)/SKILL.md falta el campo 'name:' en frontmatter."
        }
        if ($frontmatterBlock -notmatch "(?m)^description:") {
            Write-Status "ERROR" "$($folder.Name)/SKILL.md falta el campo 'description:' en frontmatter."
        }
    }
} else {
    Write-Status "WARN" "No existe el directorio $SkillsDir."
}

Write-Host ""

# ------------------------------------------------------------------------------
# 4. Presupuesto estimado de Always-On
# ------------------------------------------------------------------------------
Write-Host "Resumen de Presupuesto Always-On / Global:" -ForegroundColor Cyan
$EstimatedTokens = [Math]::Round($AlwaysOnTotalBytes / 3.8) # Aproximacion estandar tokens/bytes para espanol tecnico
Write-Host "  Bytes acumulados en Always-On: $AlwaysOnTotalBytes bytes UTF-8"
Write-Host "  Tokens estimados Always-On:    ~$EstimatedTokens tokens (Limite: $AlwaysOnTokenLimit tokens)"

if ($EstimatedTokens -gt $AlwaysOnTokenLimit) {
    Write-Status "WARN" "El presupuesto always-on estimado supera $AlwaysOnTokenLimit tokens. Las reglas grandes podrian degradarse a punteros."
} else {
    Write-Status "OK" "Presupuesto always-on en rango seguro ($EstimatedTokens / $AlwaysOnTokenLimit tokens)."
}

Write-Host ""

# ------------------------------------------------------------------------------
# Conclusion y Codigo de Salida
# ------------------------------------------------------------------------------
if ($Script:HasErrors) {
    Write-Host "Resultado: FALLO la validacion con errores criticos." -ForegroundColor Red
    exit 1
} elseif ($Script:HasWarnings) {
    Write-Host "Resultado: PASO con advertencias." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "Resultado: PASO limpiamente. Todas las reglas y habilidades son validas." -ForegroundColor Green
    exit 0
}
