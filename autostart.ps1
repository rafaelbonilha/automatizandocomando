<#
.SYNOPSIS
Muda o diretório de trabalho automaticamente do usuário

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\autostart.ps1 ou .\autostart.ps1

.EXAMPLE
Caso de Uso.:

PS> ./autostart
	📂$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab e use S e N em maíuscula para encerrar o script.

#>
try {
	$Path = Resolve-Path "$HOME/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Startup"
	if (-not(Test-Path "$Path" -pathType container)) {
		throw "Pasta de inicio automatico nao existe no caminho.: $Path"
	}
	Set-Location "$Path"
	"$Path"
	exit 0 # success
} catch {
	"Erro na linha $($_.InvocationInfo.ScriptLineNumber): $($Error[0])"
	exit 1
}
