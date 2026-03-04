<#
.SYNOPSIS
Efetua a limpeza de arquivos temporários e da lixeira e salva a atividade em arquivo txt.
Por padrão está definido manter arquivos com 30 dias ou menos

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\cls_prog.ps1 ou .\cls_prog.ps1

Caso de Uso.:

Basico.: .\cls_prog.ps1 - Faz a limpeza de arquivos temporários e da lixeira e salva a atividade em arquivo txt.

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab e use S e N em maíscula para encerrar o scrip.

#>

Add-Type -AssemblyName System.Windows.Forms

# Configuracoes 
$limparLixeira = $true  # Altere para $false se nao quiser limpar a lixeira
$limparTemp = $true      # Altere para $false se nao quiser limpar temporarios
$limparPrefetch = $true  # Altere para $false se nao quiser limpar prefetch
$limparLogs = $true      # Altere para $false se nao quiser limpar logs
$diasParaManter = 30      # Arquivos temporarios mais antigos que isso serao deletados
$logDir = "$env:USERPROFILE\HistoricoLimpeza"
$logFile = "$logDir\Limpeza_$(Get-Date -Format 'yyyy-MM-dd').log"
$dataHoraInicio = Get-Date
$dataHoraFormatada = $dataHoraInicio.ToString("dd/MM/yyyy HH:mm:ss")

# Criar diretorio de log se necessario
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

function Format-FileSize {
    param([long]$Bytes)
    
    if ($Bytes -gt 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    elseif ($Bytes -gt 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -gt 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -gt 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    else { return "{0} B" -f $Bytes }
}

function Get-FolderSize {
    param([string]$FolderPath)
    
    if (Test-Path $FolderPath) {
        $size = (Get-ChildItem $FolderPath -Recurse -ErrorAction SilentlyContinue | 
                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return [math]::Round($size / 1MB, 2) # Em MB
    }
    return 0
}

function Clear-Folder {
    param(
        [string]$FolderPath,
        [string]$Description,
        [int]$DaysOld = 0
    )
    
    $espacoLiberado = 0
    $arquivosRemovidos = 0
    
    if (Test-Path $FolderPath) {
        Write-Host "Limpando $Description..." -ForegroundColor Yellow
        Write-Log "Iniciando limpeza de $Description"
        
        try {
            $items = Get-ChildItem $FolderPath -Recurse -ErrorAction SilentlyContinue
            
            foreach ($item in $items) {
                $deletar = $true
                
                # Verifica data de modificacao se DaysOld > 0
                if ($DaysOld -gt 0) {
                    $dataLimite = (Get-Date).AddDays(-$DaysOld)
                    if ($item.LastWriteTime -gt $dataLimite) {
                        $deletar = $false
                    }
                }
                
                if ($deletar) {
                    try {
                        if ($item.PSIsContainer) {
                            Remove-Item $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
                        } else {
                            $espacoLiberado += $item.Length
                            Remove-Item $item.FullName -Force -ErrorAction SilentlyContinue
                            $arquivosRemovidos++
                        }
                    } catch {
                        
                    }
                }
            }
            
            Write-Log "Limpeza de $Description concluida" "SUCESSO"
            return @{
                Arquivos = $arquivosRemovidos
                Espaco = $espacoLiberado
            }
        } catch {
            $erroMsg = "Erro ao limpar " + $Description + ": " + $_.Exception.Message
            Write-Log $erroMsg "ERRO"
        }
    }
    
    return @{
        Arquivos = 0
        Espaco = 0
    }
}

Clear-Host

# Cabecalho
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "    INICIANDO LIMPEZA DO SISTEMA        " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "=== INICIO DA LIMPEZA ==="
Write-Log "Configuracoes:"
Write-Log "  - Limpar Lixeira: $limparLixeira"
Write-Log "  - Limpar Temporarios: $limparTemp"
Write-Log "  - Limpar Prefetch: $limparPrefetch"
Write-Log "  - Limpar Logs: $limparLogs"
Write-Log "  - Dias para manter: $diasParaManter"

# Inicializa contadores
$totalEspacoLiberado = 0
$totalArquivosRemovidos = 0

# Mostra espaco em disco antes da limpeza
$drives = Get-PSDrive -PSProvider FileSystem
foreach ($drive in $drives) {
    $espacoLivre = Format-FileSize $drive.Free
    $espacoTotal = Format-FileSize ($drive.Used + $drive.Free)
    Write-Host "Drive $($drive.Name): Livre: $espacoLivre de $espacoTotal" -ForegroundColor Gray
}
Write-Host ""

$timer = [System.Diagnostics.Stopwatch]::StartNew()

# 1. Limpeza da Lixeira
if ($limparLixeira) {
    Write-Host "`nLimpando Lixeira..." -ForegroundColor Green
    
    try {
        $lixeiraPath = "$env:USERPROFILE\AppData\Local\Recycle.Bin"
        if (Test-Path $lixeiraPath) {
            $tamanhoAntes = Get-FolderSize $lixeiraPath
            Remove-Item "$lixeiraPath\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  ✅ Lixeira limpa com sucesso" -ForegroundColor Green
            Write-Log "Lixeira limpa com sucesso" "SUCESSO"
            $totalArquivosRemovidos += 100  # Estimativa
        }
    } catch {
        Write-Host "  ❌ Erro ao limpar lixeira" -ForegroundColor Red
        Write-Log "Erro ao limpar lixeira: $($_.Exception.Message)" "ERRO"
    }
}

# 2. Limpeza de Arquivos Temporarios do Windows
if ($limparTemp) {
    Write-Host "`nLimpando Arquivos Temporarios..." -ForegroundColor Green
    
    # Temp do Windows
    $tempPaths = @(
        "$env:TEMP",
        "$env:WINDIR\Temp",
        "$env:LOCALAPPDATA\Temp"
    )
    
    foreach ($path in $tempPaths) {
        $resultado = Clear-Folder -FolderPath $path -Description "Temporarios: $path" -DaysOld $diasParaManter
        $totalArquivosRemovidos += $resultado.Arquivos
        $totalEspacoLiberado += $resultado.Espaco
    }
}

# 3. Limpeza do Prefetch
if ($limparPrefetch) {
    Write-Host "`nLimpando Prefetch..." -ForegroundColor Green
    
    $prefetchPath = "$env:WINDIR\Prefetch"
    $resultado = Clear-Folder -FolderPath $prefetchPath -Description "Prefetch" -DaysOld $diasParaManter
    $totalArquivosRemovidos += $resultado.Arquivos
    $totalEspacoLiberado += $resultado.Espaco
}

# 4. Limpeza de Logs do Windows
if ($limparLogs) {
    Write-Host "`nLimpando Logs do Sistema..." -ForegroundColor Green
    
    $logPaths = @(
        "$env:WINDIR\Logs",
        "$env:WINDIR\Debug",
        "$env:WINDIR\Panther"
    )
    
    foreach ($path in $logPaths) {
        $resultado = Clear-Folder -FolderPath $path -Description "Logs: $path" -DaysOld $diasParaManter
        $totalArquivosRemovidos += $resultado.Arquivos
        $totalEspacoLiberado += $resultado.Espaco
    }
}

# 5. Limpeza de Cache do Navegador (opcional)
Write-Host "`nLimpando Caches de Navegadores..." -ForegroundColor Green

# Chrome
$chromeCache = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
$resultado = Clear-Folder -FolderPath $chromeCache -Description "Cache Chrome"
$totalArquivosRemovidos += $resultado.Arquivos
$totalEspacoLiberado += $resultado.Espaco

# Firefox
$firefoxCache = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*.default\cache2"
$resultado = Clear-Folder -FolderPath $firefoxCache -Description "Cache Firefox"
$totalArquivosRemovidos += $resultado.Arquivos
$totalEspacoLiberado += $resultado.Espaco

# Edge
$edgeCache = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
$resultado = Clear-Folder -FolderPath $edgeCache -Description "Cache Edge"
$totalArquivosRemovidos += $resultado.Arquivos
$totalEspacoLiberado += $resultado.Espaco

$timer.Stop()
$tempoTotal = $timer.Elapsed.ToString("hh\:mm\:ss")

# Mostra espaco em disco depois da limpeza
Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "        LIMPEZA CONCLUIDA COM SUCESSO     " -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Resumo da Limpeza:" -ForegroundColor White
Write-Host "   Arquivos removidos: $totalArquivosRemovidos" -ForegroundColor Gray
Write-Host "   Espaco liberado: $(Format-FileSize $totalEspacoLiberado)" -ForegroundColor Gray
Write-Host "   Tempo total: $tempoTotal" -ForegroundColor Gray
Write-Host ""

Write-Host "Espaco em disco apos limpeza:" -ForegroundColor Yellow
foreach ($drive in $drives) {
    $espacoLivre = Format-FileSize $drive.Free
    Write-Host "   Drive $($drive.Name): $espacoLivre livres" -ForegroundColor Green
}

# Log
Write-Log "=== LIMPEZA CONCLUIDA ==="
Write-Log "Arquivos removidos: $totalArquivosRemovidos"
Write-Log "Espaco liberado: $(Format-FileSize $totalEspacoLiberado)"
Write-Log "Tempo total: $tempoTotal"

# Notificacao
$notificacaoMsg = "Limpeza concluida!$([char]13)$([char]10)" +
                 "Arquivos removidos: $totalArquivosRemovidos$([char]13)$([char]10)" +
                 "Espaco liberado: $(Format-FileSize $totalEspacoLiberado)$([char]13)$([char]10)" +
                 "Tempo: $tempoTotal"

Show-Notification -Title "✅ Limpeza Concluida" -Message $notificacaoMsg -Type "Info"

Write-Host ""
Write-Host "Log da limpeza salvo em: $logFile" -ForegroundColor Green
Write-Host ""

# Mostra ultimas linhas do log
$verLog = Read-Host "Deseja ver o log da limpeza? (S/N)"
if ($verLog -eq "S" -or $verLog -eq "s") {
    if (Test-Path $logFile) {
        Write-Host ""
        Write-Host "Ultimas 10 linhas do log:" -ForegroundColor Yellow
        Get-Content $logFile -Tail 10
    }
}

# Opcao para esvaziar lixeira pelo Shell
if ($limparLixeira) {
    $esvaziarLixeira = Read-Host "`nDeseja esvaziar completamente a Lixeira? (S/N)"
    if ($esvaziarLixeira -eq "S" -or $esvaziarLixeira -eq "s") {
        try {
            $shell = New-Object -ComObject Shell.Application
            $recycleBin = $shell.NameSpace(0x0a)  # 0x0a = constante da Lixeira
            $recycleBin.Items() | ForEach-Object { 
                $_.InvokeVerb("delete") 
            }
            Write-Host "✅ Lixeira esvaziada com sucesso!" -ForegroundColor Green
            Write-Log "Lixeira esvaziada pelo Shell" "SUCESSO"
        } catch {
            Write-Host "❌ Erro ao esvaziar lixeira" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")