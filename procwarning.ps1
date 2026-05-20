<#
.SYNOPSIS
Exibe os 5 processos que mais consomem CPU e salva o historico em arquivo txt.

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\procwarning.ps1 ou .\procwarning.ps1

Basico.: .\procwarning.ps1 - exibe os 10 processos que mais consomem CPU e registra o consumo num arquivo de log.

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab.

#>

Add-Type -AssemblyName System.Windows.Forms

# Caminho do arquivo de log (ajuste conforme necessario)
$logPath = "CaminhoOndeVcIraSalvaroArquivo\HistoricoCPU.txt"
$dataHora = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

# Obtem os top 10 processos que mais consomem CPU
$processos = Get-Process | 
    Where-Object { $_.CPU -gt 0 } | 
    Sort-Object CPU -Descending | 
    Select-Object -First 10 @{Name="Processo"; Expression={$_.Name}}, 
                            @{Name="PID"; Expression={$_.Id}}, 
                            @{Name="CPU (s)"; Expression={[math]::Round($_.CPU, 2)}},
                            @{Name="Memoria (MB)"; Expression={[math]::Round($_.WorkingSet/1MB, 2)}}

Clear-Host
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "    TOP 10 PROCESSOS - CONSUMO DE CPU    " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Registra no log
Add-Content -Path $logPath -Value "========================================="
Add-Content -Path $logPath -Value "$dataHora - TOP 10 PROCESSOS CPU"


if ($processos.Count -gt 0) {
  
    $processos | Format-Table -AutoSize
    
    
    foreach ($processo in $processos) {
        $linhaLog = "$dataHora | Processo: $($processo.Processo) | PID: $($processo.PID) | CPU: $($processo.'CPU (s)')s | Memória: $($processo.'Memória (MB)')MB"
        Add-Content -Path $logPath -Value $linhaLog
    }
    
    # Total de CPU dos top 10
    $totalCPU = ($processos | Measure-Object -Property "CPU (s)" -Sum).Sum
    $totalCPUFormatado = [math]::Round($totalCPU, 2)
    
   
    Write-Host "Total CPU (top 10): $totalCPUFormatado segundos" -ForegroundColor Yellow
    
   
    Add-Content -Path $logPath -Value "$dataHora | TOTAL CPU (top 10): $totalCPUFormatado segundos"
    
    # Destaque para o processo com maior consumo
    $topProcesso = $processos | Select-Object -First 1
    Write-Host "Processo com maior consumo: $($topProcesso.Processo) (PID: $($topProcesso.PID)) - $($topProcesso.'CPU (s)')s" -ForegroundColor Green
} else {
    Write-Host "Nenhum processo com consumo significativo de CPU encontrado." -ForegroundColor Red
    Add-Content -Path $logPath -Value "$dataHora | Nenhum processo com consumo significativo encontrado"
}

Add-Content -Path $logPath -Value ""

Write-Host ""
Write-Host "Monitoramento concluido em: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" -ForegroundColor Gray
Write-Host "Log salvo em: $logPath" -ForegroundColor Green
