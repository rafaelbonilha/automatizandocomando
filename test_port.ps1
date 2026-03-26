<#
.SYNOPSIS
Testa a conectivadade numa porta determinada e salva a atividade em arquivo txt.


.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\test_port.ps1 ou .\test_port.ps1

Caso de Uso.:

Basico.: .\test_port.ps1 - Testa a conectividade numa porta determinada e salva a atividade em arquivo txt.

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab e use S e N em maíuscula para encerrar o script.

#>

Add-Type -AssemblyName System.Windows.Forms

# Configuracoes
$logDir = "$env:USERPROFILE\HistoricoConexao"
$logFile = "$logDir\TestePorta_$(Get-Date -Format 'yyyy-MM-dd').log"

# Criar diretorio de log
if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Funcoes
function Write-Log {
    param(
        [string]$Message,
        [string]$Status = "INFO"
    )
    $timestamp = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    $logMessage = "$timestamp | $Status | $Message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage -ForegroundColor $(if ($Status -eq "ERRO") { "Red" } elseif ($Status -eq "SUCESSO") { "Green" } else { "Gray" })
}

function Show-Notification {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Type = "Info" # Info, Warning, Error
    )
    
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Application
    
    switch ($Type) {
        "Info" { $notify.Icon = [System.Drawing.SystemIcons]::Information }
        "Warning" { $notify.Icon = [System.Drawing.SystemIcons]::Warning }
        "Error" { $notify.Icon = [System.Drawing.SystemIcons]::Error }
    }
    
    $notify.BalloonTipTitle = $Title
    $notify.BalloonTipText = $Message
    $notify.Visible = $true
    $notify.ShowBalloonTip(10000) # 10 segundos
}

function Test-PortConnection {
    param(
        [string]$Hostname,
        [int]$Port,
        [int]$Timeout = 5
    )
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connection = $tcpClient.BeginConnect($Hostname, $Port, $null, $null)
        $wait = $connection.AsyncWaitHandle.WaitOne(($Timeout * 1000), $false)
        
        if ($wait) {
            $tcpClient.EndConnect($connection)
            $tcpClient.Close()
            return $true
        } else {
            $tcpClient.Close()
            return $false
        }
    } catch {
        return $false
    }
}

function Test-ValidIP {
    param([string]$IPAddress)
    
    if ($IPAddress -eq "localhost" -or $IPAddress -eq "127.0.0.1") {
        return $true
    }
    
    $regexIP = '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
    return $IPAddress -match $regexIP
}

function Test-Ping {
    param([string]$Hostname)
    
    try {
        $ping = Test-Connection -ComputerName $Hostname -Count 1 -Quiet
        return $ping
    } catch {
        return $false
    }
}

Clear-Host

# Cabecalho
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "        TESTADOR DE CONEXAO DE PORTAS     " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "=== INICIO DO TESTE DE CONEXAO ==="

# Para testar multiplas portas
$porta = 0

do {
    # IP
    Write-Host ""
    $hostname = Read-Host "Digite o IP ou hostname para testar (ou 'sair' para encerrar)"
    
    if ($hostname -eq "sair") {
        break
    }
    
    # Solicita a porta
    $portaInput = Read-Host "Digite o numero da porta (ou 'voltar' para mudar de IP)"
    
    if ($portaInput -eq "voltar") {
        continue
    }
    
    # Conversao
    if (![int]::TryParse($portaInput, [ref]$porta)) {
        Write-Log "Porta invalida: $portaInput" "ERRO"
        Show-Notification -Title "Erro" -Message "Porta invalida. Digite um numero valido." -Type "Error"
        continue
    }
    
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host "TESTANDO CONEXAO: $hostname : $porta" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Yellow
    
    Write-Log "Testando conexao: $hostname na porta $porta"
    
    # Faz teste de ping 
    Write-Host ""
    Write-Host "Testando ping..." -ForegroundColor Gray
    $pingResult = Test-Ping $hostname
    
    if ($pingResult) {
        Write-Host "✅ Ping: SUCESSO - Host respondeu" -ForegroundColor Green
        Write-Log "Ping: SUCESSO - Host respondeu"
    } else {
        Write-Host "❌ Ping: FALHA - Host nao respondeu" -ForegroundColor Yellow
        Write-Log "Ping: FALHA - Host nao respondeu" "AVISO"
    }
    
    # Testa a porta
    Write-Host ""
    Write-Host "Testando porta ${porta}..." -ForegroundColor Gray
    
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $portResult = Test-PortConnection -Hostname $hostname -Port $porta -Timeout 5
    $timer.Stop()
    $tempoResposta = [math]::Round($timer.Elapsed.TotalMilliseconds)
    
    if ($portResult) {
        Write-Host "✅ Porta ${porta}: ABERTA - Conexao estabelecida (${tempoResposta}ms)" -ForegroundColor Green
        Write-Log "Porta ${porta}: ABERTA - Conexao estabelecida (${tempoResposta}ms)" "SUCESSO"
        
        $statusMsg = "✅ Porta ${porta} ABERTA em $hostname (${tempoResposta}ms)"
        Show-Notification -Title "Conexao Bem Sucedida" -Message $statusMsg -Type "Info"
    } else {
        Write-Host "❌ Porta ${porta}: FECHADA/FILTRADA - Nao foi possivel conectar" -ForegroundColor Red
        Write-Log "Porta ${porta}: FECHADA/FILTRADA - Nao foi possivel conectar" "ERRO"
        
        $statusMsg = "❌ Porta ${porta} FECHADA/FILTRADA em $hostname"
        Show-Notification -Title "Falha na Conexao" -Message $statusMsg -Type "Error"
    }
    
    # Opcao de testar outra porta no mesmo host
    Write-Host ""
    $continuar = Read-Host "Deseja testar outra porta no mesmo host? (S/N)"
    
} while ($continuar -eq "S" -or $continuar -eq "s")

Write-Log "=== FIM DO TESTE DE CONEXAO ==="
Write-Log ""

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "           TESTES FINALIZADOS             " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Log dos testes salvo em: $logFile" -ForegroundColor Green
Write-Host ""

# Resumo
if (Test-Path $logFile) {
    Write-Host "Ultimos testes realizados:" -ForegroundColor Yellow
    Write-Host ""
    
    $ultimasLinhas = Get-Content $logFile -Tail 10
    foreach ($linha in $ultimasLinhas) {
        if ($linha -match "SUCESSO") {
            Write-Host $linha -ForegroundColor Green
        } elseif ($linha -match "ERRO") {
            Write-Host $linha -ForegroundColor Red
        } elseif ($linha -match "AVISO") {
            Write-Host $linha -ForegroundColor Yellow
        } else {
            Write-Host $linha -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Gray

$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
