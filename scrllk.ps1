<#
.SYNOPSIS
Comando para simular o uso do botão Scroll Lock por um determinado período de tempo


.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\scrllk.ps1 ou .\scrllk.ps1

Caso de Uso.:

Basico.: .\scrllk.ps1 - Comando para simular o uso do botão Scroll Lock por um determinado período de tempo

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab.

#>

Clear-Host
Write-Host "Teste de pressionamento do botão Scroll Lock." -ForegroundColor Red

$WShell = New-Object -com "Wscript.Shell"
while ($true)
{
  $WShell.sendkeys("{SCROLLLOCK}")
  Start-Sleep -Miliseconds 100
  $WShell.sendkeys("{SCROLLLOCK}")
  Start-Sleep -Seconds 240
}
  
