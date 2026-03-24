<#
.SYNOPSIS
Coleta e exibe informações sobre o servidor Windows e salva a atividade em arquivo txt.

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\server_info_v2.ps1 ou .\server_info_v2.ps1

Informações coletadas:

 Sistema operacional e hardware
 CPU, memória e disco
 Rede e conectividade
 Serviços e processos em execução
 Eventos recentes do Windows
 Usuários conectados

Caso de Uso:

Basico.: .\server_info_v2.ps1 - Exibe informações do servidor e salva em um arquivo txt.

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

#>

Add-Type -AssemblyName System.Windows.Forms

# Configs
$logDir = "$env:USERPROFILE\InfoServidor"
$logFile = "$logDir\InfoServidor_$(Get-Date -Format 'yyyy-MM-dd').log"
$reportFile = "$logDir\Relatorio_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"

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
    Write-Host $logMessage -ForegroundColor $(if ($Status -eq "ERRO") { "Red" } elseif ($Status -eq "SUCESSO") { "Green" } elseif ($Status -eq "AVISO") { "Yellow" } else { "Gray" })
}

function Show-Notification {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Type = "Info"
    )

    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Application

    switch ($Type) {
        "Info"    { $notify.Icon = [System.Drawing.SystemIcons]::Information }
        "Warning" { $notify.Icon = [System.Drawing.SystemIcons]::Warning }
        "Error"   { $notify.Icon = [System.Drawing.SystemIcons]::Error }
    }

    $notify.BalloonTipTitle = $Title
    $notify.BalloonTipText = $Message
    $notify.Visible = $true
    $notify.ShowBalloonTip(10000)
}

function Write-Section {
    param([string]$Title)
    $line = "=" * 60
    Write-Host ""
    Write-Host $line -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan
}

function Add-ToReport {
    param([string]$Content)
    Add-Content -Path $reportFile -Value $Content
}

# -------------------------------------------------------
# FUNCOES DE COLETA
# -------------------------------------------------------

function Get-SistemaOperacional {
    Write-Section "SISTEMA OPERACIONAL"
    Write-Log "Coletando informacoes do sistema operacional" "INFO"

    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS

    $uptime = (Get-Date) - $os.LastBootUpTime
    $uptimeStr = "{0} dias, {1}h {2}min" -f [math]::Floor($uptime.TotalDays), $uptime.Hours, $uptime.Minutes

    $info = [PSCustomObject]@{
        "Nome do computador"    = $env:COMPUTERNAME
        "Sistema operacional"   = $os.Caption
        "Versao"                = $os.Version
        "Build"                 = $os.BuildNumber
        "Arquitetura"           = $os.OSArchitecture
        "Fabricante"            = $cs.Manufacturer
        "Modelo"                = $cs.Model
        "Numero de serie BIOS"  = $bios.SerialNumber
        "Ultimo boot"           = $os.LastBootUpTime
        "Uptime"                = $uptimeStr
        "Fuso horario"          = (Get-TimeZone).DisplayName
    }

    $info.PSObject.Properties | ForEach-Object {
        Write-Host ("  {0,-28} : {1}" -f $_.Name, $_.Value) -ForegroundColor White
    }

    Add-ToReport "`n=== SISTEMA OPERACIONAL ==="
    $info.PSObject.Properties | ForEach-Object {
        Add-ToReport ("  {0,-28} : {1}" -f $_.Name, $_.Value)
    }
}

function Get-InfoCPU {
    Write-Section "PROCESSADOR (CPU)"
    Write-Log "Coletando informacoes de CPU" "INFO"

    $cpus = Get-CimInstance Win32_Processor

    foreach ($cpu in $cpus) {
        $info = [PSCustomObject]@{
            "Nome"                  = $cpu.Name.Trim()
            "Nucleos fisicos"       = $cpu.NumberOfCores
            "Nucleos logicos"       = $cpu.NumberOfLogicalProcessors
            "Velocidade base (MHz)" = $cpu.MaxClockSpeed
            "Arquitetura"           = switch ($cpu.Architecture) {
                                        0 { "x86" } 9 { "x64" } 5 { "ARM" } default { $cpu.Architecture }
                                      }
            "Uso atual (%)"         = $cpu.LoadPercentage
            "Status"                = $cpu.Status
        }

        $info.PSObject.Properties | ForEach-Object {
            $color = if ($_.Name -eq "Uso atual (%)" -and $_.Value -gt 80) { "Red" } else { "White" }
            Write-Host ("  {0,-28} : {1}" -f $_.Name, $_.Value) -ForegroundColor $color
        }

        Add-ToReport "`n=== PROCESSADOR ==="
        $info.PSObject.Properties | ForEach-Object {
            Add-ToReport ("  {0,-28} : {1}" -f $_.Name, $_.Value)
        }
    }
}

function Get-InfoMemoria {
    Write-Section "MEMORIA RAM"
    Write-Log "Coletando informacoes de memoria" "INFO"

    $os = Get-CimInstance Win32_OperatingSystem
    $totalGB  = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $livreGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usadoGB  = [math]::Round($totalGB - $livreGB, 2)
    $percentUso = [math]::Round(($usadoGB / $totalGB) * 100, 1)

    $info = [PSCustomObject]@{
        "Total (GB)"     = $totalGB
        "Usado (GB)"     = $usadoGB
        "Livre (GB)"     = $livreGB
        "Uso atual (%)"  = $percentUso
    }

    $info.PSObject.Properties | ForEach-Object {
        $color = if ($_.Name -eq "Uso atual (%)" -and $_.Value -gt 85) { "Red" }
                 elseif ($_.Name -eq "Uso atual (%)" -and $_.Value -gt 70) { "Yellow" }
                 else { "White" }
        Write-Host ("  {0,-28} : {1}" -f $_.Name, $_.Value) -ForegroundColor $color
    }

    # Memoria Ram Instalada
    Write-Host ""
    Write-Host "  Modulos de memoria instalados:" -ForegroundColor Yellow
    $modulos = Get-CimInstance Win32_PhysicalMemory
    foreach ($mod in $modulos) {
        $capGB = [math]::Round($mod.Capacity / 1GB, 0)
        Write-Host ("    Slot {0}: {1}GB {2} {3}MHz" -f $mod.DeviceLocator, $capGB, $mod.MemoryType, $mod.Speed) -ForegroundColor Gray
    }

    Add-ToReport "`n=== MEMORIA RAM ==="
    $info.PSObject.Properties | ForEach-Object {
        Add-ToReport ("  {0,-28} : {1}" -f $_.Name, $_.Value)
    }
}

function Get-InfoDisco {
    Write-Section "DISCOS E ARMAZENAMENTO"
    Write-Log "Coletando informacoes de disco" "INFO"

    $discos = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }

    Add-ToReport "`n=== DISCOS ==="

    foreach ($disco in $discos) {
        $totalGB  = [math]::Round($disco.Size / 1GB, 2)
        $livreGB  = [math]::Round($disco.FreeSpace / 1GB, 2)
        $usadoGB  = [math]::Round($totalGB - $livreGB, 2)
        $percentUso = if ($totalGB -gt 0) { [math]::Round(($usadoGB / $totalGB) * 100, 1) } else { 0 }

        $color = if ($percentUso -gt 90) { "Red" } elseif ($percentUso -gt 75) { "Yellow" } else { "White" }

        Write-Host ""
        Write-Host ("  Drive {0} ({1})" -f $disco.DeviceID, $disco.VolumeName) -ForegroundColor Cyan
        Write-Host ("    Total   : {0} GB" -f $totalGB) -ForegroundColor White
        Write-Host ("    Usado   : {0} GB ({1}%)" -f $usadoGB, $percentUso) -ForegroundColor $color
        Write-Host ("    Livre   : {0} GB" -f $livreGB) -ForegroundColor White

        Add-ToReport ("  Drive {0}: Total={1}GB  Usado={2}GB ({3}%)  Livre={4}GB" -f $disco.DeviceID, $totalGB, $usadoGB, $percentUso, $livreGB)
    }
}

function Get-InfoRede {
    Write-Section "REDE E CONECTIVIDADE"
    Write-Log "Coletando informacoes de rede" "INFO"

    $adaptadores = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }

    Add-ToReport "`n=== REDE ==="

    foreach ($ad in $adaptadores) {
        Write-Host ""
        Write-Host ("  Adaptador: {0}" -f $ad.Description) -ForegroundColor Cyan
        Write-Host ("    IP(s)         : {0}" -f ($ad.IPAddress -join ", ")) -ForegroundColor White
        Write-Host ("    Mascara       : {0}" -f ($ad.IPSubnet -join ", ")) -ForegroundColor White
        Write-Host ("    Gateway       : {0}" -f ($ad.DefaultIPGateway -join ", ")) -ForegroundColor White
        Write-Host ("    DNS           : {0}" -f ($ad.DNSServerSearchOrder -join ", ")) -ForegroundColor White
        Write-Host ("    MAC           : {0}" -f $ad.MACAddress) -ForegroundColor White
        Write-Host ("    DHCP ativo    : {0}" -f $ad.DHCPEnabled) -ForegroundColor White

        Add-ToReport ("  Adaptador: {0}  IP: {1}  MAC: {2}  DHCP: {3}" -f $ad.Description, ($ad.IPAddress -join ","), $ad.MACAddress, $ad.DHCPEnabled)
    }

    # Teste de conectividade
    Write-Host ""
    Write-Host "  Teste de conectividade:" -ForegroundColor Yellow
    $hosts = @("8.8.8.8", "1.1.1.1", "google.com")
    foreach ($h in $hosts) {
        $ping = Test-Connection -ComputerName $h -Count 1 -Quiet
        $status = if ($ping) { "OK" } else { "FALHOU" }
        $color  = if ($ping) { "Green" } else { "Red" }
        Write-Host ("    {0,-15} : {1}" -f $h, $status) -ForegroundColor $color
    }
}

function Get-InfoServicos {
    Write-Section "SERVICOS DO WINDOWS"
    Write-Log "Coletando informacoes de servicos" "INFO"

    $servicos = Get-Service | Sort-Object Status, DisplayName

    $rodando  = ($servicos | Where-Object { $_.Status -eq "Running" }).Count
    $parados  = ($servicos | Where-Object { $_.Status -eq "Stopped" }).Count

    Write-Host ("  Total de servicos : {0}" -f $servicos.Count) -ForegroundColor White
    Write-Host ("  Em execucao       : {0}" -f $rodando) -ForegroundColor Green
    Write-Host ("  Parados           : {0}" -f $parados) -ForegroundColor Yellow

    Write-Host ""
    Write-Host "  Servicos parados com inicio automatico (podem indicar problema):" -ForegroundColor Yellow

    $problemas = Get-WmiObject Win32_Service |
        Where-Object { $_.StartMode -eq "Auto" -and $_.State -ne "Running" } |
        Select-Object Name, DisplayName, State, StartMode

    if ($problemas.Count -eq 0) {
        Write-Host "    Nenhum servico automatico parado encontrado." -ForegroundColor Green
    } else {
        $problemas | Format-Table DisplayName, Name, State -AutoSize
        Write-Log "Encontrados $($problemas.Count) servico(s) automatico(s) parado(s)" "AVISO"
    }

    Add-ToReport "`n=== SERVICOS ==="
    Add-ToReport ("  Total: {0}  Rodando: {1}  Parados: {2}" -f $servicos.Count, $rodando, $parados)
}

function Get-TopProcessos {
    Write-Section "TOP 15 PROCESSOS POR CONSUMO"
    Write-Log "Coletando top processos" "INFO"

    $top = Get-Process |
        Where-Object { $_.Id -ne 0 } |
        Select-Object Id, ProcessName,
            @{Name="CPU (s)";   Expression={[math]::Round($_.CPU, 2)}},
            @{Name="RAM (MB)";  Expression={[math]::Round($_.WorkingSet / 1MB, 2)}},
            @{Name="Threads";   Expression={$_.Threads.Count}},
            @{Name="Resp.";     Expression={$_.Responding}} |
        Sort-Object "CPU (s)" -Descending |
        Select-Object -First 15

    $top | Format-Table -AutoSize

    Add-ToReport "`n=== TOP 15 PROCESSOS ==="
    $top | ForEach-Object {
        Add-ToReport ("  PID={0,-6} Nome={1,-25} CPU={2,-10} RAM={3}MB" -f $_.Id, $_.ProcessName, $_."CPU (s)", $_."RAM (MB)")
    }
}

function Get-EventosRecentes {
    Write-Section "EVENTOS RECENTES DO SISTEMA (ultimas 24h)"
    Write-Log "Coletando eventos recentes" "INFO"

    $desde = (Get-Date).AddHours(-24)

    $erros = Get-WinEvent -FilterHashtable @{LogName="System"; Level=2; StartTime=$desde} -ErrorAction SilentlyContinue | Select-Object -First 10
    $avisos = Get-WinEvent -FilterHashtable @{LogName="System"; Level=3; StartTime=$desde} -ErrorAction SilentlyContinue | Select-Object -First 10

    Write-Host ("  Erros encontrados  : {0}" -f $erros.Count) -ForegroundColor Red
    Write-Host ("  Avisos encontrados : {0}" -f $avisos.Count) -ForegroundColor Yellow

    if ($erros.Count -gt 0) {
        Write-Host ""
        Write-Host "  Ultimos erros:" -ForegroundColor Red
        $erros | Format-Table TimeCreated, Id, Message -AutoSize
    }

    Add-ToReport "`n=== EVENTOS (24h) ==="
    Add-ToReport ("  Erros: {0}  Avisos: {1}" -f $erros.Count, $avisos.Count)
}

function Get-UsuariosConectados {
    Write-Section "USUARIOS CONECTADOS"
    Write-Log "Coletando usuarios conectados" "INFO"

    try {
        $sessoes = query user 2>&1
        Write-Host ($sessoes | Out-String) -ForegroundColor White
        Add-ToReport "`n=== USUARIOS CONECTADOS ==="
        Add-ToReport ($sessoes | Out-String)
    } catch {
        Write-Host "  Nao foi possivel listar usuarios: $_" -ForegroundColor Yellow
    }
}

function Get-RelatorioCompleto {
    Write-Host ""
    Write-Host "Gerando relatorio completo..." -ForegroundColor Cyan

    Add-ToReport "RELATORIO DE INFORMACOES DO SERVIDOR"
    Add-ToReport ("Gerado em: {0}" -f (Get-Date -Format "dd/MM/yyyy HH:mm:ss"))
    Add-ToReport ("Servidor : {0}" -f $env:COMPUTERNAME)
    Add-ToReport ("=" * 60)

    Get-SistemaOperacional
    Get-InfoCPU
    Get-InfoMemoria
    Get-InfoDisco
    Get-InfoRede
    Get-InfoServicos
    Get-TopProcessos
    Get-EventosRecentes
    Get-UsuariosConectados

    Write-Host ""
    Write-Host "Relatorio salvo em: $reportFile" -ForegroundColor Green
    Write-Log "Relatorio completo gerado em $reportFile" "SUCESSO"
    Show-Notification -Title "Relatorio Gerado" -Message "Relatorio completo salvo em $reportFile" -Type "Info"
}

# -------------------------------------------------------
# INICIO
# -------------------------------------------------------

Clear-Host

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "       INFORMACOES DO SERVIDOR WINDOWS   " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "=== INICIO DA COLETA DE INFORMACOES ==="

do {
    Write-Host ""
    Write-Host "OPCOES DISPONIVEIS:" -ForegroundColor Yellow
    Write-Host "1. Sistema operacional e hardware"   -ForegroundColor White
    Write-Host "2. Processador (CPU)"                -ForegroundColor White
    Write-Host "3. Memoria RAM"                      -ForegroundColor White
    Write-Host "4. Discos e armazenamento"           -ForegroundColor White
    Write-Host "5. Rede e conectividade"             -ForegroundColor White
    Write-Host "6. Servicos do Windows"              -ForegroundColor White
    Write-Host "7. Top 15 processos por consumo"     -ForegroundColor White
    Write-Host "8. Eventos recentes (24h)"           -ForegroundColor White
    Write-Host "9. Usuarios conectados"              -ForegroundColor White
    Write-Host "10. Relatorio completo (salva txt)"  -ForegroundColor White
    Write-Host "0. Sair"                             -ForegroundColor White

    $opcao = Read-Host "`nEscolha uma opcao"

    switch ($opcao) {
        "1"  { Get-SistemaOperacional }
        "2"  { Get-InfoCPU }
        "3"  { Get-InfoMemoria }
        "4"  { Get-InfoDisco }
        "5"  { Get-InfoRede }
        "6"  { Get-InfoServicos }
        "7"  { Get-TopProcessos }
        "8"  { Get-EventosRecentes }
        "9"  { Get-UsuariosConectados }
        "10" { Get-RelatorioCompleto }
    }

    if ($opcao -ne "0") {
        Write-Host ""
        Write-Host "Pressione qualquer tecla para continuar..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-Host

        Write-Host "=========================================" -ForegroundColor Cyan
        Write-Host "       INFORMACOES DO SERVIDOR WINDOWS   " -ForegroundColor Cyan
        Write-Host "=========================================" -ForegroundColor Cyan
    }

} while ($opcao -ne "0")

Write-Log "=== FIM DA COLETA DE INFORMACOES ==="

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "           FERRAMENTA ENCERRADA          " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Log salvo em: $logFile" -ForegroundColor Green
Write-Host ""

if (Test-Path $logFile) {
    Write-Host "Ultimas operacoes realizadas:" -ForegroundColor Yellow
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
