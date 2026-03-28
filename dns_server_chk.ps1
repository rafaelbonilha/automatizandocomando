<#
.SYNOPSIS
Valida a velocidade do servidor dns e salva a atividade em arquivo txt.

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\dns_server_chk.ps1 ou .\dns_server_chk.ps1


Caso de Uso.:

Basico.: .\dns_server_chk.ps1 - Valida a velocidade do servidor dns e salva a atividade em um arquivo txt.

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab e use S e N em maíuscula para encerrar o script.

#>

# Configuracoes de log
$logDir  = "$env:USERPROFILE\DNSCheck"
$logFile = "$logDir\DNSCheck_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"

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

function CheckDNS {
    param($Name, $PriIPv4, $SecIPv4)

    $StopWatch = [system.diagnostics.stopwatch]::startNew()
    $null = (nslookup whitehouse.gov $PriIPv4)
    [int]$PriIPv4Elapsed = $StopWatch.Elapsed.TotalMilliseconds

    $StopWatch = [system.diagnostics.stopwatch]::startNew()
    $null = (nslookup whitehouse.gov $SecIPv4)
    [int]$SecIPv4Elapsed = $StopWatch.Elapsed.TotalMilliseconds

    $result = "   `"$Name`"; `"$PriIPv4`"; `"$PriIPv4Elapsed ms`"; `"$SecIPv4`"; `"$SecIPv4Elapsed ms`"; "
    $result

    # Grava no log
    Write-Log "$Name | Pri: $PriIPv4 ($PriIPv4Elapsed ms) | Sec: $SecIPv4 ($SecIPv4Elapsed ms)" "INFO"
}

try {
    $header = "Checking speed of public DNS servers..."
    $columns = "  `"Company`"; `"IPv4 primary`"; `"Latency in ms`"; `"IPv4 secondary`"; `"Latency in ms`"; "

    Write-Host $header
    Write-Host $columns

    # Cabecalho no log
    Add-Content -Path $logFile -Value "=================================================="
    Add-Content -Path $logFile -Value "  VELOCIDADE DO SERVIDOR DNS - $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
    Add-Content -Path $logFile -Value "  Executado por: $env:USERNAME em $env:COMPUTERNAME"
    Add-Content -Path $logFile -Value "=================================================="
    Add-Content -Path $logFile -Value $columns
    Add-Content -Path $logFile -Value ""

    CheckDNS "Cloudflare"                                                    1.1.1.1         1.0.0.1
    CheckDNS "Cloudflare with malware blocklist"                             1.1.1.2         1.0.0.2
    CheckDNS "Cloudflare with malware+adult blocklist"                       1.1.1.3         1.0.0.3
    CheckDNS "DNS.Watch"                                                     84.200.69.80    84.200.70.40
    CheckDNS "FreeDNS Vienna"                                                37.235.1.174    37.235.1.177
    CheckDNS "Google Public DNS"                                             8.8.8.8         8.8.4.4
    CheckDNS "Level3 one"                                                    4.2.2.1         4.2.2.1
    CheckDNS "Level3 two"                                                    4.2.2.2         4.2.2.2
    CheckDNS "Level3 three"                                                  4.2.2.3         4.2.2.3
    CheckDNS "Level3 four"                                                   4.2.2.4         4.2.2.4
    CheckDNS "Level3 five"                                                   4.2.2.5         4.2.2.5
    CheckDNS "Level3 six"                                                    4.2.2.6         4.2.2.6
    CheckDNS "OpenDNS Basic"                                                 208.67.222.222  208.67.220.220
    CheckDNS "OpenDNS Family Shield"                                         208.67.222.123  208.67.220.123
    CheckDNS "OpenNIC"                                                       94.247.43.254   94.247.43.254
    CheckDNS "Quad9 with malware blocklist, with DNSSEC"                     9.9.9.9         9.9.9.9
    CheckDNS "Quad9, no malware blocklist, no DNSSEC"                        9.9.9.10        9.9.9.10
    CheckDNS "Quad9, with malware blocklist, with DNSSEC, with EDNS"         9.9.9.11        9.9.9.11
    CheckDNS "Quad9, with malware blocklist, with DNSSEC, NXDOMAIN only"     9.9.9.12        9.9.9.12
    CheckDNS "Verisign Public DNS"                                           64.6.64.6       64.6.65.6

    Add-Content -Path $logFile -Value ""
    Add-Content -Path $logFile -Value "=================================================="
    Add-Content -Path $logFile -Value "  Concluido em: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
    Add-Content -Path $logFile -Value "=================================================="

    Write-Host ""
    Write-Host "✅ Log salvo em: $logFile" -ForegroundColor Green

    exit 0
} catch {
    $errorMsg = "Erro na linha $($_.InvocationInfo.ScriptLineNumber): $($Error[0])"
    Write-Log $errorMsg "ERRO"
    "⚠️ $errorMsg"
    exit 1
}