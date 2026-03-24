<#
.SYNOPSIS
Gerencia regras de firewall do Windows e salva a atividade em arquivo txt.

.NOTES
Execute o script em uma sessão PowerShell como Administrador com o comando:
powershell -STA -File Diretorio\fw_manager.ps1 ou .\fw_manager.ps1

Funcionalidades:

 Listar regras de firewall ativas
 Adicionar regra de entrada (Inbound)
 Adicionar regra de saida (Outbound)
 Remover regra por nome
 Habilitar / Desabilitar regra existente
 Exportar todas as regras para txt
 Backup e restauracao de regras

Caso de Uso:

Basico.: .\fw_manager.ps1 - Abre o menu interativo para gerenciar regras.

ATENCAO.: Execute sempre como Administrador com cuidado, script para estudos/lab.

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

#>

# Verifica se esta rodando como Admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERRO: Este script precisa ser executado como Administrador!" -ForegroundColor Red
    Write-Host "Clique com o botao direito no PowerShell e escolha 'Executar como Administrador'." -ForegroundColor Yellow
    exit 1
}

Add-Type -AssemblyName System.Windows.Forms

# Configuracoes
$logDir    = "$env:USERPROFILE\GestaoFirewall"
$logFile   = "$logDir\Firewall_$(Get-Date -Format 'yyyy-MM-dd').log"
$reportFile = "$logDir\Relatorio_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
$backupFile = "$logDir\Backup_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').wfw"

# Criar diretorio de log
if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# -------------------------------------------------------
# FUNCOES UTILITARIAS
# -------------------------------------------------------

function Write-Log {
    param(
        [string]$Message,
        [string]$Status = "INFO"
    )
    $timestamp = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    $logMessage = "$timestamp | $Status | $Message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage -ForegroundColor $(
        if     ($Status -eq "ERRO")    { "Red"   }
        elseif ($Status -eq "SUCESSO") { "Green" }
        elseif ($Status -eq "AVISO")   { "Yellow"}
        else                           { "Gray"  }
    )
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
    $notify.BalloonTipText  = $Message
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
# FUNCOES DE FIREWALL
# -------------------------------------------------------

function Get-RegrasFirewall {
    Write-Section "REGRAS DE FIREWALL ATIVAS"
    Write-Log "Listando regras de firewall" "INFO"

    $direcao = Read-Host "Filtrar por direcao? (I=Entrada / O=Saida / T=Todas)"

    $filtro = switch ($direcao.ToUpper()) {
        "I" { "Inbound"  }
        "O" { "Outbound" }
        default { $null }
    }

    $regras = if ($filtro) {
        Get-NetFirewallRule | Where-Object { $_.Direction -eq $filtro -and $_.Enabled -eq "True" }
    } else {
        Get-NetFirewallRule | Where-Object { $_.Enabled -eq "True" }
    }

    if ($regras.Count -eq 0) {
        Write-Host "  Nenhuma regra encontrada." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host ("  {0,-35} {1,-10} {2,-10} {3,-10}" -f "Nome", "Direcao", "Acao", "Perfil") -ForegroundColor Yellow
    Write-Host ("  " + "-" * 70) -ForegroundColor Gray

    foreach ($regra in $regras | Select-Object -First 30) {
        $cor = if ($regra.Action -eq "Allow") { "Green" } else { "Red" }
        Write-Host ("  {0,-35} {1,-10} {2,-10} {3,-10}" -f `
            $regra.DisplayName.Substring(0, [Math]::Min(34, $regra.DisplayName.Length)),
            $regra.Direction,
            $regra.Action,
            $regra.Profile
        ) -ForegroundColor $cor
    }

    Write-Host ""
    Write-Host "  Total de regras ativas encontradas: $($regras.Count)" -ForegroundColor Cyan
    Write-Log "Listadas $($regras.Count) regras ativas" "INFO"
}

function Add-RegraEntrada {
    Write-Section "ADICIONAR REGRA DE ENTRADA (INBOUND)"
    Write-Log "Iniciando adicao de regra de entrada" "INFO"

    $nome      = Read-Host "  Nome da regra"
    $descricao = Read-Host "  Descricao (opcional)"
    $protocolo = Read-Host "  Protocolo (TCP / UDP / Any)"
    $porta     = Read-Host "  Porta(s) (ex: 80, 443 ou 8080-8090)"
    $acao      = Read-Host "  Acao (Allow / Block)"
    $perfil    = Read-Host "  Perfil (Domain / Private / Public / Any)"
    $ipOrigem  = Read-Host "  IP de origem (deixe vazio para qualquer)"

    if ([string]::IsNullOrWhiteSpace($nome)) {
        Write-Host "  Nome da regra e obrigatorio." -ForegroundColor Red
        Write-Log "Adicao cancelada: nome vazio" "AVISO"
        return
    }

    $params = @{
        DisplayName = $nome
        Description = if ($descricao) { $descricao } else { "Criada por firewall_manager.ps1" }
        Direction   = "Inbound"
        Protocol    = if ($protocolo) { $protocolo } else { "TCP" }
        Action      = if ($acao -in @("Allow","Block")) { $acao } else { "Allow" }
        Profile     = if ($perfil)    { $perfil    } else { "Any" }
        Enabled     = "True"
    }

    if ($porta)    { $params["LocalPort"]  = $porta }
    if ($ipOrigem) { $params["RemoteAddress"] = $ipOrigem }

    try {
        New-NetFirewallRule @params | Out-Null
        Write-Log "Regra de entrada '$nome' criada com sucesso (Porta: $porta / Acao: $($params.Action))" "SUCESSO"
        Show-Notification -Title "Regra Criada" -Message "Regra de entrada '$nome' adicionada com sucesso." -Type "Info"
    } catch {
        Write-Log "Erro ao criar regra '$nome': $_" "ERRO"
        Show-Notification -Title "Erro" -Message "Falha ao criar regra: $_" -Type "Error"
    }
}

function Add-RegraSaida {
    Write-Section "ADICIONAR REGRA DE SAIDA (OUTBOUND)"
    Write-Log "Iniciando adicao de regra de saida" "INFO"

    $nome      = Read-Host "  Nome da regra"
    $descricao = Read-Host "  Descricao (opcional)"
    $protocolo = Read-Host "  Protocolo (TCP / UDP / Any)"
    $porta     = Read-Host "  Porta(s) de destino (ex: 443 ou 8080-8090)"
    $acao      = Read-Host "  Acao (Allow / Block)"
    $perfil    = Read-Host "  Perfil (Domain / Private / Public / Any)"
    $ipDestino = Read-Host "  IP de destino (deixe vazio para qualquer)"

    if ([string]::IsNullOrWhiteSpace($nome)) {
        Write-Host "  Nome da regra e obrigatorio." -ForegroundColor Red
        Write-Log "Adicao cancelada: nome vazio" "AVISO"
        return
    }

    $params = @{
        DisplayName = $nome
        Description = if ($descricao) { $descricao } else { "Criada por firewall_manager.ps1" }
        Direction   = "Outbound"
        Protocol    = if ($protocolo) { $protocolo } else { "TCP" }
        Action      = if ($acao -in @("Allow","Block")) { $acao } else { "Allow" }
        Profile     = if ($perfil)    { $perfil    } else { "Any" }
        Enabled     = "True"
    }

    if ($porta)     { $params["RemotePort"]    = $porta }
    if ($ipDestino) { $params["RemoteAddress"] = $ipDestino }

    try {
        New-NetFirewallRule @params | Out-Null
        Write-Log "Regra de saida '$nome' criada com sucesso (Porta: $porta / Acao: $($params.Action))" "SUCESSO"
        Show-Notification -Title "Regra Criada" -Message "Regra de saida '$nome' adicionada com sucesso." -Type "Info"
    } catch {
        Write-Log "Erro ao criar regra '$nome': $_" "ERRO"
        Show-Notification -Title "Erro" -Message "Falha ao criar regra: $_" -Type "Error"
    }
}

function Remove-RegraFirewall {
    Write-Section "REMOVER REGRA DE FIREWALL"
    Write-Log "Iniciando remocao de regra" "INFO"

    $nome = Read-Host "  Nome da regra a remover (exato ou parcial)"

    $regras = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*$nome*" }

    if ($regras.Count -eq 0) {
        Write-Host "  Nenhuma regra encontrada com o nome: $nome" -ForegroundColor Yellow
        Write-Log "Remocao: nenhuma regra encontrada com '$nome'" "AVISO"
        return
    }

    Write-Host ""
    Write-Host "  Regras encontradas:" -ForegroundColor Yellow
    $regras | Format-Table DisplayName, Direction, Action, Enabled -AutoSize

    $confirm = Read-Host "  Confirmar remocao de $($regras.Count) regra(s)? (S/N)"
    if ($confirm -ne "S" -and $confirm -ne "s") {
        Write-Log "Remocao cancelada pelo usuario" "AVISO"
        return
    }

    foreach ($regra in $regras) {
        try {
            Remove-NetFirewallRule -DisplayName $regra.DisplayName
            Write-Log "Regra '$($regra.DisplayName)' removida com sucesso" "SUCESSO"
        } catch {
            Write-Log "Erro ao remover regra '$($regra.DisplayName)': $_" "ERRO"
        }
    }

    Show-Notification -Title "Regra Removida" -Message "$($regras.Count) regra(s) removida(s) com sucesso." -Type "Warning"
}

function Set-StatusRegra {
    Write-Section "HABILITAR / DESABILITAR REGRA"
    Write-Log "Alterando status de regra" "INFO"

    $nome = Read-Host "  Nome da regra (exato ou parcial)"
    $regras = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*$nome*" }

    if ($regras.Count -eq 0) {
        Write-Host "  Nenhuma regra encontrada." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    $regras | Format-Table DisplayName, Direction, Action, Enabled -AutoSize

    $acao = Read-Host "  Deseja (H)abilitar ou (D)esabilitar estas regras?"

    $novoStatus = if ($acao -eq "H" -or $acao -eq "h") { "True" } else { "False" }
    $label      = if ($novoStatus -eq "True") { "habilitada" } else { "desabilitada" }

    foreach ($regra in $regras) {
        try {
            Set-NetFirewallRule -DisplayName $regra.DisplayName -Enabled $novoStatus
            Write-Log "Regra '$($regra.DisplayName)' $label com sucesso" "SUCESSO"
        } catch {
            Write-Log "Erro ao alterar regra '$($regra.DisplayName)': $_" "ERRO"
        }
    }
}

function Get-DetalhesRegra {
    Write-Section "DETALHES DE UMA REGRA"
    Write-Log "Consultando detalhes de regra" "INFO"

    $nome = Read-Host "  Nome da regra (exato ou parcial)"
    $regras = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*$nome*" }

    if ($regras.Count -eq 0) {
        Write-Host "  Nenhuma regra encontrada." -ForegroundColor Yellow
        return
    }

    foreach ($regra in $regras) {
        Write-Host ""
        Write-Host ("  {0,-25} : {1}" -f "Nome",      $regra.DisplayName)    -ForegroundColor White
        Write-Host ("  {0,-25} : {1}" -f "Descricao", $regra.Description)    -ForegroundColor Gray
        Write-Host ("  {0,-25} : {1}" -f "Direcao",   $regra.Direction)      -ForegroundColor White
        Write-Host ("  {0,-25} : {1}" -f "Acao",      $regra.Action)         -ForegroundColor $(if ($regra.Action -eq "Allow") { "Green" } else { "Red" })
        Write-Host ("  {0,-25} : {1}" -f "Perfil",    $regra.Profile)        -ForegroundColor White
        Write-Host ("  {0,-25} : {1}" -f "Habilitada", $regra.Enabled)       -ForegroundColor White

        # Porta e protocolo
        $filtroPorta = $regra | Get-NetFirewallPortFilter
        Write-Host ("  {0,-25} : {1}" -f "Protocolo", $filtroPorta.Protocol) -ForegroundColor White
        Write-Host ("  {0,-25} : {1}" -f "Porta local", $filtroPorta.LocalPort) -ForegroundColor White
        Write-Host ("  {0,-25} : {1}" -f "Porta remota", $filtroPorta.RemotePort) -ForegroundColor White

        # IP
        $filtroIP = $regra | Get-NetFirewallAddressFilter
        Write-Host ("  {0,-25} : {1}" -f "IP origem",  $filtroIP.RemoteAddress) -ForegroundColor White
        Write-Host ("  {0,-25} : {1}" -f "IP destino", $filtroIP.LocalAddress)  -ForegroundColor White
        Write-Host ""
    }
}

function Export-RegrasFirewall {
    Write-Section "EXPORTAR REGRAS PARA TXT"
    Write-Log "Exportando regras de firewall" "INFO"

    $regras = Get-NetFirewallRule

    Add-ToReport "RELATORIO DE REGRAS DE FIREWALL"
    Add-ToReport ("Gerado em: {0}" -f (Get-Date -Format "dd/MM/yyyy HH:mm:ss"))
    Add-ToReport ("Servidor : {0}" -f $env:COMPUTERNAME)
    Add-ToReport ("=" * 60)
    Add-ToReport ("Total de regras: {0}" -f $regras.Count)
    Add-ToReport ""

    foreach ($regra in $regras) {
        $filtroPorta = $regra | Get-NetFirewallPortFilter
        $filtroIP    = $regra | Get-NetFirewallAddressFilter

        Add-ToReport ("Nome      : {0}" -f $regra.DisplayName)
        Add-ToReport ("Direcao   : {0}" -f $regra.Direction)
        Add-ToReport ("Acao      : {0}" -f $regra.Action)
        Add-ToReport ("Perfil    : {0}" -f $regra.Profile)
        Add-ToReport ("Habilitada: {0}" -f $regra.Enabled)
        Add-ToReport ("Protocolo : {0}" -f $filtroPorta.Protocol)
        Add-ToReport ("Porta     : {0}" -f $filtroPorta.LocalPort)
        Add-ToReport ("IP Origem : {0}" -f $filtroIP.RemoteAddress)
        Add-ToReport ("-" * 40)
    }

    Write-Host "  Relatorio salvo em: $reportFile" -ForegroundColor Green
    Write-Log "Exportadas $($regras.Count) regras para $reportFile" "SUCESSO"
    Show-Notification -Title "Exportacao Concluida" -Message "Regras exportadas para $reportFile" -Type "Info"
}

function Backup-RegrasFirewall {
    Write-Section "BACKUP DAS REGRAS DE FIREWALL"
    Write-Log "Realizando backup das regras" "INFO"

    try {
        netsh advfirewall export "$backupFile" | Out-Null
        Write-Host "  Backup salvo em: $backupFile" -ForegroundColor Green
        Write-Log "Backup realizado com sucesso em $backupFile" "SUCESSO"
        Show-Notification -Title "Backup Realizado" -Message "Backup salvo em $backupFile" -Type "Info"
    } catch {
        Write-Log "Erro ao realizar backup: $_" "ERRO"
    }
}

function Restore-RegrasFirewall {
    Write-Section "RESTAURAR REGRAS DE FIREWALL"
    Write-Log "Iniciando restauracao de regras" "INFO"

    $arquivos = Get-ChildItem -Path $logDir -Filter "*.wfw" | Sort-Object LastWriteTime -Descending

    if ($arquivos.Count -eq 0) {
        Write-Host "  Nenhum arquivo de backup (.wfw) encontrado em $logDir" -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "  Backups disponiveis:" -ForegroundColor Yellow
    $arquivos | Select-Object -First 5 | ForEach-Object {
        Write-Host ("    {0}" -f $_.FullName) -ForegroundColor White
    }

    $caminho = Read-Host "`n  Informe o caminho completo do backup a restaurar"

    if (!(Test-Path $caminho)) {
        Write-Host "  Arquivo nao encontrado: $caminho" -ForegroundColor Red
        return
    }

    $confirm = Read-Host "  ATENCAO: isso substituira as regras atuais. Confirmar? (S/N)"
    if ($confirm -ne "S" -and $confirm -ne "s") {
        Write-Log "Restauracao cancelada pelo usuario" "AVISO"
        return
    }

    try {
        netsh advfirewall import "$caminho" | Out-Null
        Write-Log "Regras restauradas com sucesso de $caminho" "SUCESSO"
        Show-Notification -Title "Restauracao Concluida" -Message "Regras restauradas de $caminho" -Type "Info"
    } catch {
        Write-Log "Erro ao restaurar regras: $_" "ERRO"
    }
}

# -------------------------------------------------------
# INICIO
# -------------------------------------------------------

Clear-Host

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "      GESTAO DE FIREWALL - WINDOWS       " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "=== INICIO DA GESTAO DE FIREWALL ==="

do {
    Write-Host ""
    Write-Host "OPCOES DISPONIVEIS:" -ForegroundColor Yellow
    Write-Host "1.  Listar regras ativas"               -ForegroundColor White
    Write-Host "2.  Adicionar regra de entrada"         -ForegroundColor White
    Write-Host "3.  Adicionar regra de saida"           -ForegroundColor White
    Write-Host "4.  Remover regra"                      -ForegroundColor White
    Write-Host "5.  Habilitar / Desabilitar regra"      -ForegroundColor White
    Write-Host "6.  Ver detalhes de uma regra"          -ForegroundColor White
    Write-Host "7.  Exportar todas as regras (txt)"     -ForegroundColor White
    Write-Host "8.  Fazer backup das regras (.wfw)"     -ForegroundColor White
    Write-Host "9.  Restaurar regras de backup"         -ForegroundColor White
    Write-Host "0.  Sair"                               -ForegroundColor White

    $opcao = Read-Host "`nEscolha uma opcao"

    switch ($opcao) {
        "1" { Get-RegrasFirewall    }
        "2" { Add-RegraEntrada      }
        "3" { Add-RegraSaida        }
        "4" { Remove-RegraFirewall  }
        "5" { Set-StatusRegra       }
        "6" { Get-DetalhesRegra     }
        "7" { Export-RegrasFirewall }
        "8" { Backup-RegrasFirewall }
        "9" { Restore-RegrasFirewall }
    }

    if ($opcao -ne "0") {
        Write-Host ""
        Write-Host "Pressione qualquer tecla para continuar..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-Host

        Write-Host "=========================================" -ForegroundColor Cyan
        Write-Host "      GESTAO DE FIREWALL - WINDOWS       " -ForegroundColor Cyan
        Write-Host "=========================================" -ForegroundColor Cyan
    }

} while ($opcao -ne "0")

Write-Log "=== FIM DA GESTAO DE FIREWALL ==="

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
        if     ($linha -match "SUCESSO") { Write-Host $linha -ForegroundColor Green  }
        elseif ($linha -match "ERRO")    { Write-Host $linha -ForegroundColor Red    }
        elseif ($linha -match "AVISO")   { Write-Host $linha -ForegroundColor Yellow }
        else                             { Write-Host $linha -ForegroundColor Gray   }
    }
}

Write-Host ""
Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")