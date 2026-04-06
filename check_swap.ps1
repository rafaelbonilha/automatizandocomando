<#
.SYNOPSIS
Verifica o uso de memória swap e avisa se estiver sendo usada mais de 75%, registra a atividade em log.

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\check_swap.ps1 ou .\check_swap.ps1

.EXAMPLE
Caso de Uso.:

Basico.: .\check_swap.ps1

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab e use S e N em maíuscula para encerrar o script.

#>

# Configs
$logDir    = "$env:USERPROFILE\SwapMonitor"
$logFile   = "$logDir\SwapMonitor_$(Get-Date -Format 'yyyy-MM-dd').log"
$limiteSwap = 75  # percentual de alerta
 
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
 
function Get-SwapInfo {
    $os = Get-CimInstance Win32_OperatingSystem
 
    $totalSwapMB = [math]::Round($os.TotalVirtualMemorySize / 1KB, 2)
    $livreSwapMB = [math]::Round($os.FreeVirtualMemory      / 1KB, 2)
    $usadoSwapMB = [math]::Round($totalSwapMB - $livreSwapMB, 2)
    $percentUso  = if ($totalSwapMB -gt 0) {
        [math]::Round(($usadoSwapMB / $totalSwapMB) * 100, 1)
    } else { 0 }
 
    return [PSCustomObject]@{
        TotalMB  = $totalSwapMB
        UsadoMB  = $usadoSwapMB
        LivreMB  = $livreSwapMB
        Percentual = $percentUso
    }
}
 
function Show-SwapStatus {
    param($swap)
 
    $line = "=" * 55
 
    Write-Host ""
    Write-Host $line                                      -ForegroundColor Cyan
    Write-Host "  MONITORAMENTO DE MEMORIA SWAP"          -ForegroundColor Cyan
    Write-Host $line                                      -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("  {0,-20} : {1} MB" -f "Total",  $swap.TotalMB)  -ForegroundColor White
    Write-Host ("  {0,-20} : {1} MB" -f "Usado",  $swap.UsadoMB)  -ForegroundColor White
    Write-Host ("  {0,-20} : {1} MB" -f "Livre",  $swap.LivreMB)  -ForegroundColor White
 
    $corPercent = if     ($swap.Percentual -gt 90) { "Red"    }
                  elseif ($swap.Percentual -gt 75) { "Yellow" }
                  else                             { "Green"  }
 
    Write-Host ("  {0,-20} : {1}%" -f "Uso atual", $swap.Percentual) -ForegroundColor $corPercent
    Write-Host ("  {0,-20} : {1}%" -f "Limite de alerta", $limiteSwap) -ForegroundColor Gray
    Write-Host ""
    Write-Host $line -ForegroundColor Cyan
}
 
# INICIO
 
try {
    Write-Log "=== INICIO DO MONITORAMENTO DE SWAP ===" "INFO"
 
    $swap = Get-SwapInfo
 
    Show-SwapStatus -swap $swap
 
    Write-Log "Swap: Total=$($swap.TotalMB)MB | Usado=$($swap.UsadoMB)MB | Livre=$($swap.LivreMB)MB | Uso=$($swap.Percentual)%" "INFO"
 
    if ($swap.Percentual -gt $limiteSwap) {
        Write-Host ""
        Write-Host "  ALERTA: Uso de swap em $($swap.Percentual)% - acima do limite de $limiteSwap%!" -ForegroundColor Red
        Write-Host "  Verifique os processos consumindo mais memoria." -ForegroundColor Yellow
        Write-Host ""
 
        Write-Log "ALERTA: Uso de swap em $($swap.Percentual)% - acima do limite de $limiteSwap%!" "AVISO"
 
        # Exibe top 5 processos por uso de memoria
        Write-Host "  Top 5 processos por consumo de memoria:" -ForegroundColor Yellow
        $top5 = Get-Process |
            Sort-Object WorkingSet -Descending |
            Select-Object -First 5 |
            Select-Object ProcessName,
                @{Name="RAM (MB)"; Expression={[math]::Round($_.WorkingSet / 1MB, 2)}}
 
        $top5 | Format-Table -AutoSize
 
        $top5 | ForEach-Object {
            Write-Log "  Processo: $($_.ProcessName) | RAM: $($_.'RAM (MB)') MB" "INFO"
        }
 
    } else {
        Write-Host ""
        Write-Host "  OK: Uso de swap em $($swap.Percentual)% - dentro do limite de $limiteSwap%." -ForegroundColor Green
        Write-Host ""
        Write-Log "OK: Uso de swap em $($swap.Percentual)% - dentro do limite." "SUCESSO"
    }
 
    Write-Log "=== FIM DO MONITORAMENTO DE SWAP ===" "INFO"
    Write-Host "  Log salvo em: $logFile" -ForegroundColor Green
    Write-Host ""
 
    exit 0
 
} catch {
    $errorMsg = "Erro na linha $($_.InvocationInfo.ScriptLineNumber): $($Error[0])"
    Write-Log $errorMsg "ERRO"
    Write-Host "ERRO: $errorMsg" -ForegroundColor Red
    exit 1
}