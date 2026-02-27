<#
.SYNOPSIS
Efetua o backup de arquivos de um diretório para outro e salva a atividade em arquivo txt.

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\bkp_prog.ps1 ou .\bkp_prog.ps1

Caso de Uso.:

Basico.: .\bkp_prog.ps1 - faz o backup de arquivos de um diretório para outro e salva a atividade em arquivo txt.

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab e use S e N em maíscula para encerrar o scrip.

#>

Add-Type -AssemblyName System.Windows.Forms

# Configuracoes do Backup
$origem = "$env:USERPROFILE\PastaAFazeroBKP"
$destino = "EnderecoDeDestinoDoBKP"
$nomeBackup = "PastaBkp" # Pode colocar o nome que achar melhor

# Configuracoes de Log
$logDir = "DiretorioOndeFicaraOsLogs\HistoricoBkp"
$logFile = "$logDir\Backup_$(Get-Date -Format 'yyyy-MM-dd').log"
$dataHoraInicio = Get-Date
$dataHoraFormatada = $dataHoraInicio.ToString("dd/MM/yyyy HH:mm:ss")

# Criar diretorio de log se nao existir
if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Funcao de gravar o log
function Write-Log {
    param(
        [string]$Message,
        [string]$Status = "INFO"
    )
    $timestamp = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    $logMessage = "$timestamp | $Status | $Message"
    Add-Content -Path $logFile -Value $logMessage
}
# Gera a notificacao
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

# Funcao para definir o tamanho da pasta
function Get-FolderSize {
    param([string]$FolderPath)
    
    if (Test-Path $FolderPath) {
        $size = (Get-ChildItem $FolderPath -Recurse -ErrorAction SilentlyContinue | 
                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return [math]::Round($size / 1MB, 2) # Em MB
    }
    return 0
}

# Funcao para formatar tamanho
function Format-FileSize {
    param([long]$Bytes)
    
    if ($Bytes -gt 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    elseif ($Bytes -gt 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -gt 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -gt 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    else { return "{0} B" -f $Bytes }
}

Clear-Host

# Cabecalho
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "        INICIANDO PROCESSO DE BACKUP      " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "=== INICIO DO BACKUP: $nomeBackup ==="
Write-Log "Origem: $origem"
Write-Log "Destino: $destino"

# Verifica se a origem existe
if (!(Test-Path $origem)) {
    $erroMsg = "ERRO: Pasta de origem nao encontrada: $origem"
    Write-Host $erroMsg -ForegroundColor Red
    Write-Log $erroMsg "ERRO"
    Show-Notification -Title "Erro no Backup" -Message $erroMsg -Type "Error"
    exit 1
}

# Verifica espaço em disco no destino
$destinoDrive = Split-Path $destino -Qualifier
if ($destinoDrive) {
    $freeSpace = (Get-PSDrive -Name $destinoDrive.Trim(':')).Free
    $freeSpaceFormatado = Format-FileSize $freeSpace
    Write-Host "Espaco livre no destino: $freeSpaceFormatado" -ForegroundColor Yellow
    Write-Log "Espaco livre no destino: $freeSpaceFormatado"
}

# Calcula tamanho da origem
Write-Host "Calculando tamanho da origem..." -ForegroundColor Yellow
$tamanhoOrigem = Get-FolderSize $origem
$tamanhoOrigemFormatado = if ($tamanhoOrigem -gt 1024) { 
    "{0:N2} GB" -f ($tamanhoOrigem / 1024) 
} else { 
    "{0:N2} MB" -f $tamanhoOrigem 
}
Write-Host "Tamanho da origem: $tamanhoOrigemFormatado" -ForegroundColor Yellow
Write-Log "Tamanho da origem: $tamanhoOrigemFormatado"

# Cria nome da pasta com data/hora para backup incremental (opcional)
$dataHoraArquivo = Get-Date -Format "yyyy-MM-dd_HHmmss"
$destinoComData = Join-Path $destino "$nomeBackup`_$dataHoraArquivo"

Write-Host ""
Write-Host "Copiando arquivos..." -ForegroundColor Green
Write-Log "Iniciando copia dos arquivos..."

try {
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    
    # Realiza o backup 
    Copy-Item -Path $origem -Destination $destinoComData -Recurse -Force -ErrorAction Stop
    
    $timer.Stop()
    $tempoTotal = $timer.Elapsed.ToString("hh\:mm\:ss")
    
    # Verifica se o backup foi criado
    if (Test-Path $destinoComData) {
        # Calcula tamanho do backup
        $tamanhoBackup = Get-FolderSize $destinoComData
        $tamanhoBackupFormatado = if ($tamanhoBackup -gt 1024) { 
            "{0:N2} GB" -f ($tamanhoBackup / 1024) 
        } else { 
            "{0:N2} MB" -f $tamanhoBackup 
        }
        
        # Conta numero de arquivos
        $numArquivos = (Get-ChildItem $destinoComData -Recurse -File -ErrorAction SilentlyContinue).Count
        $numPastas = (Get-ChildItem $destinoComData -Recurse -Directory -ErrorAction SilentlyContinue).Count
        
        Write-Host ""
        Write-Host "=========================================" -ForegroundColor Green
        Write-Host "        BACKUP CONCLUIDO COM SUCESSO      " -ForegroundColor Green
        Write-Host "=========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Resumo do Backup:" -ForegroundColor White
        Write-Host "   Origem: $origem" -ForegroundColor Gray
        Write-Host "   Destino: $destinoComData" -ForegroundColor Gray
        Write-Host "   Arquivos copiados: $numArquivos" -ForegroundColor Gray
        Write-Host "   Pastas criadas: $numPastas" -ForegroundColor Gray
        Write-Host "   Tamanho do backup: $tamanhoBackupFormatado" -ForegroundColor Gray
        Write-Host "   Tempo total: $tempoTotal" -ForegroundColor Gray
        Write-Host ""
        
        # Log detalhado
        Write-Log "=== BACKUP CONCLUIDO COM SUCESSO ==="
        Write-Log "Destino final: $destinoComData"
        Write-Log "Arquivos copiados: $numArquivos"
        Write-Log "Pastas criadas: $numPastas"
        Write-Log "Tamanho do backup: $tamanhoBackupFormatado"
        Write-Log "Tempo total: $tempoTotal"
        
        # Mostra notificacao
        $notificacaoMsg = "Backup de '$nomeBackup' concluido!$([char]13)$([char]10)" +
                         "Arquivos: $numArquivos | Tamanho: $tamanhoBackupFormatado$([char]13)$([char]10)" +
                         "Tempo: $tempoTotal"
        
        Show-Notification -Title "✅ Backup Concluido" -Message $notificacaoMsg -Type "Info"
        
        # Abre a pasta de destino? (opcional)
        $resposta = Read-Host "Deseja abrir a pasta de destino? (S/N)"
        if ($resposta -eq "S" -or $resposta -eq "s") {
            explorer $destinoComData
        }
    }
} catch {
    $timer.Stop()
    $erroMsg = "ERRO durante o backup: $($_.Exception.Message)"
    Write-Host ""
    Write-Host $erroMsg -ForegroundColor Red
    Write-Host "Detalhes: $($_.Exception.StackTrace)" -ForegroundColor Red
    
    Write-Log $erroMsg "ERRO"
    Write-Log "Detalhes: $($_.Exception.Message)" "ERRO"
    
    Show-Notification -Title "❌ Erro no Backup" -Message $erroMsg -Type "Error"
}

Write-Log "=== FIM DO BACKUP ==="
Write-Log ""

Write-Host ""
Write-Host "Log do backup salvo em: $logFile" -ForegroundColor Green
Write-Host ""

# Mostra ultimas linhas do log (opcional)
$verLog = Read-Host "Deseja ver o log do backup? (S/N)"
if ($verLog -eq "S" -or $verLog -eq "s") {
    if (Test-Path $logFile) {
        Write-Host ""
        Write-Host "Ultimas 10 linhas do log:" -ForegroundColor Yellow
        Get-Content $logFile -Tail 10
    }
}

Write-Host ""
Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
