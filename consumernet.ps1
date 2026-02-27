<#
.SYNOPSIS
Exibe os 10 processos que mais consomem banda, avisa o usuário e salva o historico em arquivo txt.

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\consumernet.ps1 ou .\consumernet.ps1

Caso de Uso.:

Basico.: .\consumernet.ps1 - 10 processos que mais consomem banda, avisa o usuário e salva o historico em arquivo txt.

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab.

#>
Add-Type -AssemblyName System.Windows.Forms

# Caminho do arquivo de log 
$logPath = "CaminhoOndeVcIraSalvaroArquivo\HistoricoRede.txt"
$dataHora = Get-Date -Format "dd/MM/yyyy HH:mm:ss"


$diretorio = Split-Path $logPath -Parent
if (!(Test-Path $diretorio)) {
    New-Item -ItemType Directory -Path $diretorio -Force
}

# Funcao para obter dados de redes
function Get-NetworkStats {
    # Obtem todas as conexões TCP ativas
    $connections = Get-NetTCPConnection | Where-Object { $_.State -ne "Listen" }
    
    # Obtem os processos
    $processes = Get-Process
    $processStats = @{}
    
    foreach ($conn in $connections) {
        $process = $processes | Where-Object { $_.Id -eq $conn.OwningProcess }
        
        if ($process) {
            $processName = $process.ProcessName
            $processPID = $process.Id
            
            # Cada conexao ativa consome aproximadamente 0.1 Mbps (valor estimado)
            $bandwidthEstimate = 0.1 # Mbps por conexão
            
            if (-not $processStats.ContainsKey($processPID)) {
                $processStats[$processPID] = @{
                    Name = $processName
                    PID = $processPID
                    Connections = 0
                    BandwidthMbps = 0
                    RemoteAddresses = @()
                }
            }
            
            $processStats[$processPID].Connections++
            
            # Adiciona endereco remoto
            if ($conn.RemoteAddress -ne "::" -and $conn.RemoteAddress -ne "0.0.0.0") {
                $remoteInfo = "$($conn.RemoteAddress):$($conn.RemotePort)"
                if ($processStats[$processPID].RemoteAddresses -notcontains $remoteInfo) {
                    $processStats[$processPID].RemoteAddresses += $remoteInfo
                }
            }
        }
    }
    
    # Calcula a banda estimada para cada processo
    $resultados = @()
    foreach ($processId in $processStats.Keys) {
        $proc = $processStats[$processId]
        $proc.BandwidthMbps = [math]::Round($proc.Connections * 0.1, 2)
        
        $resultados += [PSCustomObject]@{
            Processo = $proc.Name
            ProcessoId = $proc.ProcessId
            Conexoes = $proc.Connections
            BandaMbps = $proc.BandwidthMbps
            RemoteAddresses = $proc.RemoteAddresses
        }
    }
    
    return $resultados
}

Clear-Host
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "   TOP 10 PROCESSOS - CONSUMO DE BANDA DE REDE   " -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Coletando informacoes de rede..." -ForegroundColor Yellow

# Obtem as estatisticas de rede
$networkStats = Get-NetworkStats

# Estimativa de banda
$topProcessos = $networkStats | 
    Sort-Object -Property Conexoes -Descending | 
    Select-Object -First 10

# Registra no log
Add-Content -Path $logPath -Value "==============================================="
Add-Content -Path $logPath -Value "$dataHora - TOP 10 PROCESSOS - BANDA DE REDE"
Add-Content -Path $logPath -Value "==============================================="

if ($topProcessos.Count -gt 0) {
    # Prepara os dados para exibicao com enderecos remotos truncados
    $displayProcessos = @()
    foreach ($proc in $topProcessos) {
        $remoteStr = ""
        if ($proc.RemoteAddresses.Count -gt 0) {
            $remoteStr = ($proc.RemoteAddresses -join ", ")
            if ($remoteStr.Length -gt 40) {
                $remoteStr = $remoteStr.Substring(0, 37) + "..."
            }
        } else {
            $remoteStr = "Nenhum"
        }
        
        $displayProcessos += [PSCustomObject]@{
            Processo = $proc.Processo
            "ID Processo" = $proc.ProcessoId 
            Conexoes = $proc.Conexoes
            "Banda (Mbps)" = $proc.BandaMbps
            "Principais Destinos" = $remoteStr
        }
    }
    
    Write-Host ""
    $displayProcessos | Format-Table -AutoSize
    
    # Registra no log
    foreach ($processo in $topProcessos) {
        $remoteInfo = $processo.RemoteAddresses -join ", "
        if ($remoteInfo.Length -eq 0) {
            $remoteInfo = "Nenhum"
        }
        
        $linhaLog = "$dataHora | Processo: $($processo.Processo) | PID: $($processo.ProcessoId) | Conexoes: $($processo.Conexoes) | Banda: $($processo.BandaMbps) Mbps | Destinos: $remoteInfo"
        
        if ($linhaLog.Length -gt 500) {
            $linhaLog = $linhaLog.Substring(0, 497) + "..."
        }
        
        Add-Content -Path $logPath -Value $linhaLog
    }
    
    # Total de banda estimada
    $totalBanda = ($topProcessos | Measure-Object -Property BandaMbps -Sum).Sum
    $totalBandaFormatado = [math]::Round($totalBanda, 2)    
    $totalConexoes = ($topProcessos | Measure-Object -Property Conexoes -Sum).Sum
    
    Write-Host ""
    Write-Host "Total Banda Estimada (top 10): $totalBandaFormatado Mbps" -ForegroundColor Yellow
    Write-Host "Total Conexoes Ativas (top 10): $totalConexoes" -ForegroundColor Yellow
    
    Add-Content -Path $logPath -Value "$dataHora | TOTAL BANDA ESTIMADA (top 10): $totalBandaFormatado Mbps"
    Add-Content -Path $logPath -Value "$dataHora | TOTAL CONEXOES (top 10): $totalConexoes"
    
    # Destaque para o processo de maior consumo
    $topProcesso = $topProcessos | Select-Object -First 1
    Write-Host ""
    Write-Host "Processo com maior consumo: $($topProcesso.Processo) (PID: $($topProcesso.PID))" -ForegroundColor Green
    Write-Host "Conexoes ativas: $($topProcesso.Conexoes) | Banda estimada: $($topProcesso.BandaMbps) Mbps" -ForegroundColor Green
    
    # Alerta se consumo for muito alto
    if ($topProcesso.Conexoes -gt 75) {
        Write-Host ""
        Write-Host "⚠️  ALERTA: Processo $($topProcesso.Processo) tem muitas conexoes ativas!" -ForegroundColor Red -BackgroundColor Yellow
        Add-Content -Path $logPath -Value "$dataHora | ⚠️ ALERTA: Processo $($topProcesso.Processo) tem $($topProcesso.Conexoes) conexoes ativas"
        
        # Notificacao
        try {
            $notify = New-Object System.Windows.Forms.NotifyIcon
            $notify.Icon = [System.Drawing.SystemIcons]::Warning
            $notify.BalloonTipTitle = "Alerta de Rede"
            $notify.BalloonTipText = "Processo $($topProcesso.Processo) esta usando muitas conexoes de rede! ($($topProcesso.Conexoes) conexões)"
            $notify.Visible = $true
            $notify.ShowBalloonTip(5000)
        } catch {
            Write-Host "Nao foi possivel mostrar notificacao" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "Nenhum processo com consumo significativo de rede encontrado." -ForegroundColor Red
    Add-Content -Path $logPath -Value "$dataHora | Nenhum processo com consumo significativo de rede encontrado"
}

Add-Content -Path $logPath -Value ""

Write-Host ""
Write-Host "Monitoramento concluido em: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" -ForegroundColor Gray
Write-Host "Log salvo em: $logPath" -ForegroundColor Green
Write-Host ""
Write-Host "Observacoes:" -ForegroundColor Yellow
Write-Host "- A banda e estimada baseada no numero de conexoes ativas" -ForegroundColor Yellow
Write-Host "- Cada conexao ativa conta como aproximadamente 0.1 Mbps" -ForegroundColor Yellow
Write-Host "- Para monitoramento em tempo real, execute o script periodicamente" -ForegroundColor Yellow
Write-Host ""
Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
