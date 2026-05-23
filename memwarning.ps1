<#
.SYNOPSIS
Valida o consumo de memoria RAM e emite alerta se o consumo estiver acima de 75%.

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\memwarning.ps1 ou .\memwarning.ps1

Basico.: .\hdwarning.ps1 - irá mostrar o consumo de disco, avisando o usuario se ultrapassar 75% e registra o consumo num 
arquivo de log.

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab.

#>

Add-Type -AssemblyName System.Windows.Forms

# Caminho do arquivo de log
$logPath = "CaminhoOndeVcIraSalvaroArquivo\HistoricoMemoria.txt"

# Captura data/hora da execucao
$dataHora = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

# Obtem informacoes da memoria do sistema
$memoria = Get-CimInstance Win32_OperatingSystem

# Calcula os valores de memoria e converte o resultado em GB
$totalGB = [math]::Round($memoria.TotalVisibleMemorySize/1MB, 2)
$livreGB = [math]::Round($memoria.FreePhysicalMemory/1MB, 2)
$usadoGB = [math]::Round($totalGB - $livreGB, 2)
$uso = (($totalGB - $livreGB) / $totalGB) * 100
$usoFormatado = [math]::Round($uso, 2)

# Texto para log
$linhaLog = "$dataHora | Memoria RAM | Total: $totalGB GB | Usado: $usadoGB GB | Livre: $livreGB GB | Uso: $usoFormatado%"

# Grava o historico no arquivo txt
Add-Content -Path $logPath -Value $linhaLog

# Exibe alerta se o consumo de memoria for acima de 75%
if ($uso -gt 75) {
    [System.Windows.Forms.MessageBox]::Show(
        "ALERTA: Memoria RAM esta com $usoFormatado% de uso!`nTotal: $totalGB GB | Usado: $usadoGB GB | Livre: $livreGB GB",
        "Consumo de Memoria RAM",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    
    # Tambem exibe no console em vermelho
    Write-Host "ALERTA: Memoria RAM esta com $usoFormatado% de uso!" -ForegroundColor Red
    Write-Host "Total: $totalGB GB | Usado: $usadoGB GB | Livre: $livreGB GB" -ForegroundColor Yellow
} else {
    Write-Host "Memoria RAM esta saudavel ($usoFormatado% de uso)." -ForegroundColor Green
    Write-Host "Total: $totalGB GB | Usado: $usadoGB GB | Livre: $livreGB GB" -ForegroundColor Cyan
}
