<#
.SYNOPSIS
Verifica o uso de dns cache e faz a limpeza, registra a atividade em log.

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\cls_dnscache.ps1 ou .\cls_dnscache.ps1

.EXAMPLE
Caso de Uso.:

Basico.: .\cls_dnscache.ps1 - Limpa o DNS cache e registra a atividade em log.

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab e use S e N em maíuscula para encerrar o script.

#>

# Verifica se o terminal está com o perfil Admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERRO: Este script precisa ser executado como Administrador!" -ForegroundColor Red
    Write-Host "Clique com o botao direito no PowerShell e escolha 'Executar como Administrador'." -ForegroundColor Yellow
    exit 1
}
 
# Configs
$logDir   = "$env:USERPROFILE\DNSFlush"
$logFile  = "$logDir\DNSFlush_$(Get-Date -Format 'yyyy-MM-dd').log"
$limiteEntradas = 0  # quantidade de entradas esperada apos limpeza
 
if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
 
# Funcoes
 
function Write-Log {
    param(
        [string]$Message,
        [string]$Status = "INFO"
    )
    $timestamp  = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    $logMessage = "$timestamp | $Status | $Message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage -ForegroundColor $(
        if     ($Status -eq "ERRO")    { "Red"    }
        elseif ($Status -eq "SUCESSO") { "Green"  }
        elseif ($Status -eq "AVISO")   { "Yellow" }
        else                           { "Gray"   }
    )
}
 
function Write-Section {
    param([string]$Title)
    $line = "=" * 55
    Write-Host ""
    Write-Host $line           -ForegroundColor Cyan
    Write-Host "  $Title"     -ForegroundColor Cyan
    Write-Host $line           -ForegroundColor Cyan
}
 
function Add-ToReport {
    param([string]$Content)
    Add-Content -Path $logFile -Value $Content
}
 
function Get-CacheAtual {
    Write-Section "CACHE DNS ATUAL"
    Write-Log "Consultando cache DNS atual" "INFO"
 
    $cache = Get-DnsClientCache -ErrorAction SilentlyContinue
 
    if (-not $cache -or $cache.Count -eq 0) {
        Write-Host "  Cache DNS vazio." -ForegroundColor Yellow
        Write-Log "Cache DNS vazio antes da limpeza" "AVISO"
        return 0
    }
 
    Write-Host ""
    Write-Host ("  {0,-40} {1,-8} {2}" -f "Nome", "Tipo", "Dado") -ForegroundColor Yellow
    Write-Host ("  " + "-" * 65) -ForegroundColor Gray
 
    foreach ($entrada in $cache | Select-Object -First 20) {
        Write-Host ("  {0,-40} {1,-8} {2}" -f `
            $entrada.Entry,
            $entrada.Type,
            $entrada.Data
        ) -ForegroundColor White
    }
 
    if ($cache.Count -gt 20) {
        Write-Host ("  ... e mais {0} entradas." -f ($cache.Count - 20)) -ForegroundColor Gray
    }
 
    Write-Host ""
    Write-Host ("  Total de entradas no cache: {0}" -f $cache.Count) -ForegroundColor Cyan
    Write-Log "Cache DNS com $($cache.Count) entradas antes da limpeza" "INFO"
 
    Add-ToReport ""
    Add-ToReport "=== CACHE DNS ANTES DA LIMPEZA ==="
    Add-ToReport "  Total de entradas: $($cache.Count)"
    foreach ($entrada in $cache) {
        Add-ToReport ("  {0,-40} {1,-8} {2}" -f $entrada.Entry, $entrada.Type, $entrada.Data)
    }
 
    return $cache.Count
}
 
function Clear-CacheDNS {
    Write-Section "LIMPANDO CACHE DNS"
    Write-Log "Iniciando limpeza do cache DNS" "INFO"
 
    try {
        Clear-DnsClientCache
        Write-Host "  Cache DNS limpo com sucesso!" -ForegroundColor Green
        Write-Log "Cache DNS limpo com sucesso via Clear-DnsClientCache" "SUCESSO"
    } catch {
        # Fallback para ipconfig /flushdns
        Write-Host "  Tentando via ipconfig /flushdns..." -ForegroundColor Yellow
        Write-Log "Fallback para ipconfig /flushdns" "AVISO"
 
        $resultado = ipconfig /flushdns 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Cache DNS limpo com sucesso via ipconfig!" -ForegroundColor Green
            Write-Log "Cache DNS limpo com sucesso via ipconfig /flushdns" "SUCESSO"
        } else {
            Write-Host "  Erro ao limpar cache DNS: $resultado" -ForegroundColor Red
            Write-Log "Erro ao limpar cache DNS: $resultado" "ERRO"
            throw "Falha na limpeza do cache DNS"
        }
    }
}
 
function Confirm-LimpezaCache {
    Write-Section "VERIFICANDO CACHE APOS LIMPEZA"
    Write-Log "Verificando cache DNS apos limpeza" "INFO"
 
    Start-Sleep -Seconds 1
 
    $cache = Get-DnsClientCache -ErrorAction SilentlyContinue
    $quantidade = if ($cache) { $cache.Count } else { 0 }
 
    if ($quantidade -eq $limiteEntradas) {
        Write-Host "  Cache DNS confirmado como vazio." -ForegroundColor Green
        Write-Log "Limpeza confirmada: cache com $quantidade entradas" "SUCESSO"
    } else {
        Write-Host ("  Cache ainda possui {0} entrada(s) — pode ser preenchimento automatico do sistema." -f $quantidade) -ForegroundColor Yellow
        Write-Log "Cache com $quantidade entradas apos limpeza (preenchimento automatico do SO)" "AVISO"
    }
 
    Add-ToReport ""
    Add-ToReport "=== CACHE DNS APOS LIMPEZA ==="
    Add-ToReport "  Entradas restantes: $quantidade"
}
 
function Restart-ServicoDNS {
    Write-Section "REINICIAR SERVICO DNS CLIENT"
 
    $confirmar = Read-Host "  Deseja reiniciar o servico DNS Client? Isso pode causar lentidao momentanea. (S/N)"
    if ($confirmar -ne "S" -and $confirmar -ne "s") {
        Write-Log "Reinicio do servico DNS cancelado pelo usuario" "AVISO"
        return
    }
 
    try {
        Write-Log "Reiniciando servico DNS Client" "INFO"
        Restart-Service -Name "Dnscache" -Force
        Write-Host "  Servico DNS Client reiniciado com sucesso!" -ForegroundColor Green
        Write-Log "Servico DNS Client reiniciado com sucesso" "SUCESSO"
    } catch {
        Write-Host "  Erro ao reiniciar servico DNS: $_" -ForegroundColor Red
        Write-Log "Erro ao reiniciar servico DNS: $_" "ERRO"
    }
}
 
# Inicio do Script
 
try {
    Clear-Host
 
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "       LIMPEZA DE CACHE DNS              " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
 
    Add-ToReport "=================================================="
    Add-ToReport "  LIMPEZA DE CACHE DNS - $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
    Add-ToReport "  Executado por: $env:USERNAME em $env:COMPUTERNAME"
    Add-ToReport "=================================================="
 
    Write-Log "=== INICIO DA LIMPEZA DE CACHE DNS ===" "INFO"
 
    # Passo 1: Exibe cache atual
    $totalAntes = Get-CacheAtual
 
    # Passo 2: Confirmacao do usuario
    Write-Host ""
    $confirmar = Read-Host "  Deseja limpar o cache DNS agora? (S/N)"
    if ($confirmar -ne "S" -and $confirmar -ne "s") {
        Write-Log "Limpeza cancelada pelo usuario" "AVISO"
        Write-Host "  Operacao cancelada." -ForegroundColor Yellow
        exit 0
    }
 
    # Passo 3: Limpa o cache
    Clear-CacheDNS
 
    # Passo 4: Confirma limpeza
    Confirm-LimpezaCache
 
    # Passo 5: Reinicia servico (opcional)
    Restart-ServicoDNS
 
    # Rodape
    Add-ToReport ""
    Add-ToReport "=================================================="
    Add-ToReport "  Concluido em: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
    Add-ToReport "=================================================="
 
    Write-Log "=== FIM DA LIMPEZA DE CACHE DNS ===" "INFO"
 
    Write-Host ""
    Write-Host "  Log salvo em: $logFile" -ForegroundColor Green
    Write-Host ""
 
    exit 0
 
} catch {
    $errorMsg = "Erro na linha $($_.InvocationInfo.ScriptLineNumber): $($Error[0])"
    Write-Log $errorMsg "ERRO"
    Write-Host "ERRO: $errorMsg" -ForegroundColor Red
    exit 1
}