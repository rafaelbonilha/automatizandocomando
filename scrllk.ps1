# Comando para simular o uso do botão Scroll Lock por um determinado período de tempo
# Curso de PowerShell

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
  
