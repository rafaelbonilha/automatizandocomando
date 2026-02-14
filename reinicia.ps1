<#
.SYNOPSIS
Efetua a reinicializacao do computador e avisa o usuario.

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\reinicia.ps1

Caso de Uso.:

Basico.: .\reinicia.ps1 - vai reiniciar o computador, avisando o usuario.

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab.

#>


# Configuracoes
$tempoEspera = 60  # segundos
$mensagem = "ATENCAO: O computador sera reiniciado em $tempoEspera segundos. Salve seu trabalho!"

# Funcao para mostrar pop-up
function Show-Message {
    param(
        [string]$Message,
        [string]$Title = "AVISO DE REINICIALIZAÇÃO",
        [int]$Timeout = 10
    )
    
    # Usa WScript.Shell para criar pop-up
    $wshell = New-Object -ComObject Wscript.Shell
    $wshell.Popup($Message, $Timeout, $Title, 48)  # 48 = ícone de aviso
}

# Funcao para mostrar mensagem no console para todos os usuários
function Show-ConsoleMessage {
    param([string]$Message)
    
    # Escreve no console atual
    Write-Host "`n$Message" -ForegroundColor Yellow
    
    # Tenta escrever em todos os consoles (requer admin)
    try {
        $sessions = quser 2>$null
        if ($sessions) {
            $users = $sessions | ForEach-Object {
                if ($_ -match '^\s*(\S+)\s+(\S+)') {
                    $matches[2]
                }
            }
            
            foreach ($user in $users) {
                if ($user -and $user -ne 'console') {
                    $messageEvent = New-Object System.Diagnostics.EventLog
                    $messageEvent.Source = "User32"
                    $messageEvent.WriteEntry($Message, "Information", 1000)
                }
            }
        }
    } catch {
        # Ignora erros ao tentar enviar para outros usuarios
    }
}

# Mensagem inicial
Show-Message -Message $mensagem -Timeout 15
Show-ConsoleMessage -Message $mensagem

# Contagem regressiva
for ($i = $tempoEspera; $i -gt 0; $i -= 10) {
    Start-Sleep -Seconds 10
    
    if ($i -gt 10) {
        $msgRestante = "Reinicialização em $i segundos..."
        Write-Host $msgRestante -ForegroundColor Yellow
        
        if ($i -le 30) {
            Show-Message -Message $msgRestante -Timeout 5
        }
    }
}

# Ultimos 10 segundos
for ($i = 10; $i -gt 0; $i--) {
    $msgFinal = "Reinicialização em $i segundos..."
    Write-Host $msgFinal -ForegroundColor Red
    
    if ($i -le 5) {
        Show-Message -Message $msgFinal -Timeout 1
    }
    
    Start-Sleep -Seconds 1
}

# Mensagem final
Show-Message -Message "REINICIANDO AGORA!" -Timeout 2
Write-Host "REINICIANDO O COMPUTADOR..." -ForegroundColor Red

# Reinicia o computador
Restart-Computer -Force