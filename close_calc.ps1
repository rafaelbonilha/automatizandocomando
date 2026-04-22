<#
.SYNOPSIS
Verifica o uso da calculadora e encerra a mesma, registra a atividade em log.

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\close_calc.ps1 ou .\close_calc.ps1

.EXAMPLE
Caso de Uso.:

Basico.: .\close_calc.ps1

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab e use S e N em maíuscula para encerrar o script.

#>

# Configs
$logDir  = "$env:USERPROFILE\KillCalc"
$logFile = "$logDir\KillCalc_$(Get-Date -Format 'yyyy-MM-dd').log"

if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Funcs

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

function Show-Header {
    $line = "=" * 55
    Write-Host ""
    Write-Host $line                              -ForegroundColor Cyan
    Write-Host "  ENCERRAMENTO DA CALCULADORA"   -ForegroundColor Cyan
    Write-Host $line                              -ForegroundColor Cyan
    Write-Host ""
}

function Get-CalcProcesses {
    # Nomes de processo conhecidos da Calculadora no Windows
    $nomesCalc = @(
        "Calculator",         # Calculadora moderna (UWP - Windows 10/11)
        "calc",               # Calculadora classica (Win7/legado)
        "CalculatorApp"       # Variante UWP em algumas versoes
    )
    return $nomesCalc
}

function Find-Calc {
    $encontrados = @()
    $nomes = Get-CalcProcesses

    foreach ($nome in $nomes) {
        $procs = Get-Process -Name $nome -ErrorAction SilentlyContinue
        foreach ($proc in $procs) {
            $encontrados += [PSCustomObject]@{
                PID     = $proc.Id
                Nome    = $proc.ProcessName
                RAM_MB  = [math]::Round($proc.WorkingSet / 1MB, 2)
            }
        }
    }

    return $encontrados
}

function Show-CalcStatus {
    param($processos)

    $line = "=" * 55

    Write-Host ("  {0,-10} {1,-30} {2}" -f "PID", "Processo", "RAM (MB)") -ForegroundColor White
    Write-Host ("  " + "-" * 50) -ForegroundColor Gray

    foreach ($proc in $processos) {
        Write-Host ("  {0,-10} {1,-30} {2}" -f $proc.PID, $proc.Nome, $proc.RAM_MB) -ForegroundColor White
    }

    Write-Host ""
    Write-Host ("  Total encontrado: {0} processo(s)" -f $processos.Count) -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan
    Write-Host ""
}

function Stop-Calc {
    param($processos)

    $encerrados = 0
    $falhas     = 0

    foreach ($proc in $processos) {
        Write-Log "Encerrando processo: $($proc.Nome) (PID: $($proc.PID))" "INFO"

        try {
            Stop-Process -Id $proc.PID -Force -ErrorAction Stop
            Write-Host "  Processo $($proc.Nome) (PID: $($proc.PID)) encerrado com sucesso." -ForegroundColor Green
            Write-Log "Processo $($proc.Nome) (PID: $($proc.PID)) encerrado com sucesso" "SUCESSO"
            $encerrados++
        } catch {
            Write-Host "  Falha ao encerrar $($proc.Nome) (PID: $($proc.PID)): $_" -ForegroundColor Red
            Write-Log "Falha ao encerrar $($proc.Nome) (PID: $($proc.PID)): $_" "ERRO"
            $falhas++
        }
    }

    Write-Host ""
    Write-Host ("  Resultado: {0} encerrado(s) | {1} falha(s)" -f $encerrados, $falhas) -ForegroundColor Cyan
    Write-Log "Resultado final: $encerrados encerrado(s), $falhas falha(s)" "INFO"
}

# INÍCIO DO SCRIPT

try {
    Show-Header
    Write-Log "=== INICIO DO ENCERRAMENTO DA CALCULADORA ===" "INFO"

    # Passo 1: Busca processos
    $encontrados = Find-Calc

    if (-not $encontrados -or $encontrados.Count -eq 0) {
        Write-Host "  Nenhum processo de calculadora encontrado em execucao." -ForegroundColor Yellow
        Write-Host ""
        Write-Log "Nenhum processo de calculadora encontrado" "AVISO"

    } else {
        # Passo 2: Exibe processos encontrados
        Write-Host "  Processos de calculadora encontrados:" -ForegroundColor White
        Show-CalcStatus -processos $encontrados

        # Passo 3: Confirmação do usuário
        $confirmar = Read-Host "  Deseja encerrar todos os processos listados? (S/N)"
        if ($confirmar -ne "S" -and $confirmar -ne "s") {
            Write-Log "Operacao cancelada pelo usuario" "AVISO"
            Write-Host "  Operacao cancelada." -ForegroundColor Yellow
            Write-Host ""
            exit 0
        }

        Write-Host ""

        # Passo 4: Encerra os processos
        Stop-Calc -processos $encontrados
    }

    Write-Log "=== FIM DO ENCERRAMENTO DA CALCULADORA ===" "INFO"
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





























