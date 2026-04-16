<#
.SYNOPSIS
Encerra a loja da Microsoft no servidor

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\fecha_store.ps1 ou .\fecha_store.ps1

.EXAMPLE
Caso de Uso.:

Basico.: .\fecha_store.ps1 - Encerra a loja da Microsoft no servidor

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab e use S e N em maíuscula para encerrar o script.

#>

TaskKill /im WinStore.App.exe /f /t
if ($lastExitCode -ne "0") {
	& "$PSScriptRoot/give-reply.ps1" "Atencao, Loja da Microsoft foi encerrada."
	exit 1
}
exit 0 # Em caso de sucesso