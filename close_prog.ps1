<#
.SYNOPSIS
Verifica o uso de um programa e encerra a mesmo pelo nome, registra a atividade em log.

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\close_prog.ps1 ou .\close_prog.ps1

.EXAMPLE
Caso de Uso.:

Basico.: .\close_prog.ps1

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab e use S e N em maíuscula para encerrar o script.

#>

param(
    [string[]]$ProcessNames = @("calc.exe") # Mude o nome ou passe ele como parametro
)

# Configs
$logDir  = "$env:USERPROFILE\KillPrograms"
$logFile = "$logDir\KillPrograms_$(Get-Date -Format 'yyyy-MM-dd').log"

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
    Write-Host $line -ForegroundColor Cyan
    Write-Host "  ENCERRAMENTO DE PROGRAMAS" -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan
    Write-Host ""
}

function Find-Processes {
    param($names)

    $encontrados = @()

    foreach ($nome in $names) {
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

function Show-ProcessStatus {
    param($processos)

    $line = "=" * 55

    Write-Host ("  {0,-10} {1,-30} {2}" -f "PID", "Processo", "RAM (MB)")
    Write-Host ("  " + "-" * 50) -ForegroundColor Gray

    foreach ($proc in $processos) {
        Write-Host ("  {0,-10} {1,-30} {2}" -f $proc.PID, $proc.Nome, $proc.RAM_MB)
    }

    Write-Host ""
    Write-Host ("  Total encontrado: {0} processo(s)" -f $processos.Count) -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan
    Write-Host ""
}

function Stop-Processes {
    param($processos)

    $encerrados = 0
    $falhas     = 0

    foreach ($proc in $processos) {
        Write-Log "Encerrando processo: $($proc.Nome) (PID: $($proc.PID))"

        try {
            Stop-Process -Id $proc.PID -Force -ErrorAction Stop
            Write-Host "  $($proc.Nome) (PID: $($proc.PID)) encerrado." -ForegroundColor Green
            Write-Log "Encerrado com sucesso: $($proc.Nome)" "SUCESSO"
            $encerrados++
        } catch {
            Write-Host "  Falha ao encerrar $($proc.Nome): $_" -ForegroundColor Red
            Write-Log "Falha ao encerrar $($proc.Nome): $_" "ERRO"
            $falhas++
        }
    }

    Write-Host ""
    Write-Host ("  Resultado: {0} encerrado(s) | {1} falha(s)" -f $encerrados, $falhas) -ForegroundColor Cyan
    Write-Log "Resultado: $encerrados sucesso(s), $falhas falha(s)"
}

# Inicio

try {
    Show-Header
    Write-Log "=== INICIO DO ENCERRAMENTO ==="

    $encontrados = Find-Processes -names $ProcessNames

    if (-not $encontrados) {
        Write-Host "  Nenhum processo encontrado." -ForegroundColor Yellow
        Write-Log "Nenhum processo encontrado" "AVISO"
    }
    else {
        Write-Host "  Processos encontrados:"
        Show-ProcessStatus -processos $encontrados

        $confirmar = Read-Host "  Deseja encerrar todos? (S/N)"
        if ($confirmar -notin @("S","s")) {
            Write-Host "  Operacao cancelada." -ForegroundColor Yellow
            Write-Log "Cancelado pelo usuario" "AVISO"
            exit
        }

        Stop-Processes -processos $encontrados
    }

    Write-Log "=== FIM ==="
    Write-Host ""
    Write-Host "Log: $logFile" -ForegroundColor Green

} catch {
    Write-Log "Erro: $_" "ERRO"
    Write-Host "Erro: $_" -ForegroundColor Red
}
