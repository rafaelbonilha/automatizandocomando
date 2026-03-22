<#
.SYNOPSIS
Coleta informações sobre o servidor.

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\server_info.ps1 ou .\server_info.ps1

Caso de Uso.:

Basico.: .\server_info.ps1 - Coleta informações sobre o servidor.

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab e use S e N em maíuscula para encerrar o script.

#>

Write-Host "Script para gerar informacoes sobre o Servidor"
Write-host "Detalhes da Bios.:"
Get-CimInstance -ClassName Win32_BIOS
Write-Host "Arquitetura do Processador.:"
Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -Property SystemType
Write-Host "Dominio, Fabricante, Modelo, Nome do Servidor e Quantidade de Memoria instalada no servidor.: "
Get-CimInstance -ClassName Win32_ComputerSystem
Write-Host "Ultimas atualizacoes instaladas.:"
Get-CimInstance -ClassName Win32_QuickFixEngineering
Write-Host "Detalhes do Sistema Operacional.:"
Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -Property Build*,OSType,ServicePack*
Write-Host "Usuarios Existentes no servidor.:"
Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -Property *user*