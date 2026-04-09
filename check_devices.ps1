<#
.SYNOPSIS
Verifica se os dispositivos conectados estão ok, registra a atividade em log.

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\check_swap.ps1 ou .\check_devices.ps1.
Precisa ter permissão de admin e o pacote smartmontools em.: https://www.smartmontools.org/wiki/Download

.EXAMPLE
Caso de Uso.:

Basico.: .\check_devices.ps1 - Valida os dispositivos e salva a atividade em log.

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab e use S e N em maíuscula para encerrar o script.

#>

# Verifica se esta rodando como Admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERRO: Este script precisa ser executado como Administrador!" -ForegroundColor Red
    exit 1
}

# Verifica se o pacote smartctl esta instalado
$smartctl = Get-Command smartctl -ErrorAction SilentlyContinue
if (-not $smartctl) {
    Write-Host "ERRO: 'smartctl' nao encontrado." -ForegroundColor Red
    Write-Host "Instale o smartmontools em: https://www.smartmontools.org/wiki/Download" -ForegroundColor Yellow
    exit 1
}

# CONFIGURACOES

$logDir   = "$env:USERPROFILE\SmartCheck"
$logFile  = "$logDir\SmartCheck_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# FUNCOES

function Write-Log {
    param(
        [string]$Message,
        [string]$Status = "INFO"
    )
    $timestamp  = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    $logMessage = "$timestamp | $Status | $Message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage -ForegroundColor $(
        if     ($Status -eq "ERRO")    { "Red"    }
        elseif ($Status -eq "SUCESSO") { "Green"  }
        elseif ($Status -eq "AVISO")   { "Yellow" }
        else                           { "Gray"   }
    )
}

function Write-Section {
    param([string]$Title)
    $line = "=" * 60
    Write-Host ""
    Write-Host $line         -ForegroundColor Cyan
    Write-Host "  $Title"   -ForegroundColor Cyan
    Write-Host $line         -ForegroundColor Cyan
}

function Add-ToReport {
    param([string]$Content)
    Add-Content -Path $logFile -Value $Content
}

function Get-Discos {
    # Lista todos os discos fisicos via smartctl
    $scan = smartctl --scan 2>&1
    $discos = @()
    foreach ($linha in $scan) {
        if ($linha -match "^(/dev/\S+|\\\\\.\\PhysicalDrive\d+)") {
            $discos += $matches[0]
        }
    }
    return $discos
}

function Get-SmartAtributo {
    param(
        [string[]]$SmartOutput,
        [string]$NomeAtributo
    )
    $linha = $SmartOutput | Where-Object { $_ -match $NomeAtributo } | Select-Object -First 1
    if ($linha -match '\s+(\d+)\s+\d+\s+\d+\s+(\S+)\s+\d+\s+\d+\s+(\d+)') {
        return $matches[3]  # RAW_VALUE
    }
    return "N/A"
}

function Check-Disco {
    param([string]$Disco)

    Write-Section "DISCO: $Disco"
    Write-Log "Verificando disco $Disco" "INFO"

    # Info geral
    $info = smartctl -i $Disco 2>&1
    $saude = smartctl -H $Disco 2>&1
    $atributos = smartctl -A $Disco 2>&1
    
    $modelo     = [string]($info | Where-Object { $_ -match "Device Model|Product" }        | Select-Object -First 1) -replace '.*:\s*', ''
    $serie      = [string]($info | Where-Object { $_ -match "Serial Number" }               | Select-Object -First 1) -replace '.*:\s*', ''
    $tipo       = [string]($info | Where-Object { $_ -match "Rotation Rate|Solid State" }   | Select-Object -First 1) -replace '.*:\s*', ''
    $firmware   = [string]($info | Where-Object { $_ -match "Firmware Version" }            | Select-Object -First 1) -replace '.*:\s*', ''
    $capacidade = [string]($info | Where-Object { $_ -match "User Capacity" }               | Select-Object -First 1) -replace '.*:\s*', ''

    # Status S.M.A.R.T.
    $statusLinha = $saude | Where-Object { $_ -match "SMART overall-health" }
    $statusOk    = $statusLinha -match "PASSED"
    $statusTexto = if ($statusOk) { "PASSED" } else { "FAILED" }
    $statusCor   = if ($statusOk) { "Green"  } else { "Red"    }

    # Atributos
    $temperatura        = Get-SmartAtributo $atributos "Temperature_Celsius|Airflow_Temperature"
    $horasUso           = Get-SmartAtributo $atributos "Power_On_Hours"
    $errosRealocados    = Get-SmartAtributo $atributos "Reallocated_Sector_Ct"
    $setoresPendentes   = Get-SmartAtributo $atributos "Current_Pending_Sector"
    $errosLeitura       = Get-SmartAtributo $atributos "Raw_Read_Error_Rate"
    $errosUncorrectable = Get-SmartAtributo $atributos "Offline_Uncorrectable"
    $contagemLigamentos = Get-SmartAtributo $atributos "Power_Cycle_Count"

    # Exibe no terminal
    Write-Host ("  {0,-28} : {1}" -f "Modelo",          $modelo.Trim())     -ForegroundColor White
    Write-Host ("  {0,-28} : {1}" -f "Numero de serie", $serie.Trim())      -ForegroundColor White
    Write-Host ("  {0,-28} : {1}" -f "Firmware",        $firmware.Trim())   -ForegroundColor White
    Write-Host ("  {0,-28} : {1}" -f "Capacidade",      $capacidade.Trim()) -ForegroundColor White
    Write-Host ("  {0,-28} : {1}" -f "Tipo",            $tipo.Trim())       -ForegroundColor White
    Write-Host ""
    Write-Host ("  {0,-28} : {1}" -f "Status S.M.A.R.T.", $statusTexto) -ForegroundColor $statusCor

    # Cor da temperatura
    $tempNum  = if ($temperatura -match '^\d+$') { [int]$temperatura } else { 0 }
    $tempCor  = if ($tempNum -gt 60) { "Red" } elseif ($tempNum -gt 45) { "Yellow" } else { "Green" }
    Write-Host ("  {0,-28} : {1} C" -f "Temperatura", $temperatura) -ForegroundColor $tempCor

    Write-Host ("  {0,-28} : {1} h" -f "Horas de uso",          $horasUso)           -ForegroundColor White
    Write-Host ("  {0,-28} : {1}"   -f "Ciclos de ligamento",    $contagemLigamentos) -ForegroundColor White

    # Alertas de atributos 
    $erroRealocadoNum  = if ($errosRealocados    -match '^\d+$') { [int]$errosRealocados    } else { 0 }
    $setorPendenteNum  = if ($setoresPendentes   -match '^\d+$') { [int]$setoresPendentes   } else { 0 }
    $erroUncorrectNum  = if ($errosUncorrectable -match '^\d+$') { [int]$errosUncorrectable } else { 0 }
    $corRealocados  = if ($erroRealocadoNum  -gt 0) { "Red" } else { "Green" }
    $corPendentes   = if ($setorPendenteNum  -gt 0) { "Red" } else { "Green" }
    $corUncorrect   = if ($erroUncorrectNum  -gt 0) { "Red" } else { "Green" }

    Write-Host ("  {0,-28} : {1}" -f "Setores realocados",      $errosRealocados)    -ForegroundColor $corRealocados
    Write-Host ("  {0,-28} : {1}" -f "Setores pendentes",       $setoresPendentes)   -ForegroundColor $corPendentes
    Write-Host ("  {0,-28} : {1}" -f "Erros nao corrigiveis",   $errosUncorrectable) -ForegroundColor $corUncorrect
    Write-Host ("  {0,-28} : {1}" -f "Erros de leitura (raw)",  $errosLeitura)       -ForegroundColor White

    # Resumo
    Write-Host ""
    if (-not $statusOk) {
        Write-Host "  *** ATENCAO: Este disco REPROVOU no teste S.M.A.R.T.! ***" -ForegroundColor Red
        Write-Log "FALHA S.M.A.R.T. no disco $Disco ($modelo)" "ERRO"
    } elseif ($erroRealocadoNum -gt 0 -or $setorPendenteNum -gt 0 -or $erroUncorrectNum -gt 0) {
        Write-Host "  *** AVISO: Disco passou no S.M.A.R.T. mas tem atributos criticos! ***" -ForegroundColor Yellow
        Write-Log "AVISO: Disco $Disco passou no S.M.A.R.T. mas tem atributos criticos" "AVISO"
    } else {
        Write-Host "  Disco saudavel." -ForegroundColor Green
        Write-Log "OK: Disco $Disco saudavel (PASSED)" "SUCESSO"
    }

    # Grava no log
    Add-ToReport ""
    Add-ToReport "=== DISCO: $Disco ==="
    Add-ToReport "  Modelo          : $($modelo.Trim())"
    Add-ToReport "  Serie           : $($serie.Trim())"
    Add-ToReport "  Status SMART    : $statusTexto"
    Add-ToReport "  Temperatura     : $temperatura C"
    Add-ToReport "  Horas de uso    : $horasUso h"
    Add-ToReport "  Setores realoc. : $errosRealocados"
    Add-ToReport "  Setores pend.   : $setoresPendentes"
    Add-ToReport "  Erros uncorr.   : $errosUncorrectable"
    Add-ToReport "  Erros leitura   : $errosLeitura"
    Add-ToReport ""
}

# INICIO

try {
    Clear-Host

    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "   VALIDACAO S.M.A.R.T. - HDD / SSD     " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""

    # Cabecalho no log
    Add-ToReport "=================================================="
    Add-ToReport "  VALIDACAO S.M.A.R.T. - $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
    Add-ToReport "  Executado por: $env:USERNAME em $env:COMPUTERNAME"
    Add-ToReport "=================================================="
    Add-ToReport ""

    Write-Log "=== INICIO DA VALIDACAO S.M.A.R.T. ===" "INFO"

    $discos = Get-Discos

    if ($discos.Count -eq 0) {
        Write-Host "  Nenhum disco encontrado pelo smartctl." -ForegroundColor Yellow
        Write-Log "Nenhum disco encontrado" "AVISO"
        exit 0
    }

    Write-Host "  Discos encontrados: $($discos.Count)" -ForegroundColor Cyan
    Write-Log "Discos encontrados: $($discos.Count)" "INFO"

    foreach ($disco in $discos) {
        Check-Disco -Disco $disco
    }

    Add-ToReport "=================================================="
    Add-ToReport "  Concluido em: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
    Add-ToReport "=================================================="

    Write-Log "=== FIM DA VALIDACAO S.M.A.R.T. ===" "INFO"
    Write-Host ""
    Write-Host "  Log salvo em: $logFile" -ForegroundColor Green
    Write-Host ""

    exit 0

} catch {
    $errorMsg = "Erro na linha $($_.InvocationInfo.ScriptLineNumber): $($Error[0])"
    Write-Log $errorMsg "ERRO"
    Write-Host "ERRO: $errorMsg" -ForegroundColor Red
    exit 1
}

