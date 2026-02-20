<#
.SYNOPSIS
Valida o consumo de disco e emite alerta se o consumo estiver acima de 75%.

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\hdwarning.ps1

Caso de Uso.:

Basico.: .\hdwarning.ps1 - irá mostrar o consumo de disco, avisando o usuario se ultrapassar 75% e registra o consumo num 
arquivo de log.

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab.

#>
Add-Type -AssemblyName System.Windows.Forms

# Caminho do arquivo de log
$logPath = "CaminhoOndeVciraSalvaroArquivo\HistoricoDisco.txt"

# Captura data/hora da execucao
$dataHora = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

$discos = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
foreach ($d in $discos) {
    $uso = (($d.Size - $d.FreeSpace) / $d.Size) * 100
    $usoFormatado = [math]::Round($uso,2)
    $totalGB = [math]::Round($d.Size/1GB,2)
    $livreGB = [math]::Round($d.FreeSpace/1GB,2)
    $usadoGB = $totalGB - $livreGB

    # Texto para log
    $linhaLog = "$dataHora | Disco $($d.DeviceID) | Total: $totalGB GB | Usado: $usadoGB GB | Livre: $livreGB GB | Uso: $usoFormatado%"

    # Grava o historico no arquivo txt
    Add-Content -Path $logPath -Value $linhaLog

    # Exibe alerta se o consumo de disco for acima de 75%
    if ($uso -gt 75) {
        [System.Windows.Forms.MessageBox]::Show(
            "ALERTA: Disco $($d.DeviceID) esta com $usoFormatado% de uso!",
            "Consumo de Disco",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
    } else {
        Write-Host "Disco $($d.DeviceID) esta saudavel ($usoFormatado% de uso)." -ForegroundColor Green
    }
}



