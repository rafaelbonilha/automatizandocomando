<#
.SYNOPSIS
Pressiona uma tecla (padrão Print Screen PrtSc) em intervalos regulares.

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\autoprtsc.ps1

Caso de Uso.:

Basico.: .\autoprtsc.ps1 - vai pressionar a tecla Print Screen a cada 20 segundos

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab.

#>

Add-Type -AssemblyName System.Windows.Forms

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 20000 # 20 segundos em milissegundos
$counter = 1
# controle de captura com o prt sc 
$timer.Add_Tick({
    [System.Windows.Forms.SendKeys]::SendWait("{PRTSC}")
    Write-Host "[$counter] Print Screen capturado em: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Green
    $script:counter++
})

Write-Host "Script iniciado. Pressione CTRL+C para parar." -ForegroundColor Cyan
$timer.Start()

# Mantem o script em execucao
while ($true) {
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 100
}