<#
.SYNOPSIS
Pressiona uma tecla (padrão F5) em intervalos regulares.

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\autoF5.ps1

Casos de Uso.:

Basico.: .\autoF5.ps1 - vai pressionar a tecla F5 a cada 25 segundos

Com modificador.: .\autoF5.ps1 -Tecla "{F5}" -Modificador "Ctrl"

Com janela de navegador específico.: .\autoF5.ps1 -JanelaAlvo "Firefox" -Intervalo 20

Com limite de execuções.: .\autoF5.ps1 -ContadorMaximo 10 -Intervalo 10

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab.

#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Tecla = "{F5}",

    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 3600)]
    [int]$Intervalo = 25,

    [Parameter(Mandatory=$false)]
    [ValidateRange(0,300)]
    [int]$DelayInicial = 5,

    [Parameter(Mandatory=$false)]
    [string]$LogArquivo = "",

    [Parameter(Mandatory=$false)]
    [switch]$Silencioso,

    [Parameter(Mandatory=$false)]
    [int]$ContadorMaximo = 0,

    [Parameter(Mandatory=$false)]
    [string]$JanelaAlvo = "",

    [Parameter(Mandatory=$false)]
    [ValidateSet("Normal", "Alt", "Ctrl", "Shift", "AltCtrl", "AltShift", "CtrlShift", "AltCtrlShift")]
    [string]$Modificador = "Normal"
)

# Configuração inicial
$ErrorActionPreference = "Stop"
$global:parar = $false
$VersaoScript = "2.0"
$DataInicio = Get-Date

# Carrega assemblies necessários
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

# Mapeamento de modificadores
$modificadoresMap = @{
    "Normal" = ""
    "Alt" = "%"
    "Ctrl" = "^"
    "Shift" = "+"
    "AltCtrl" = "%^"
    "AltShift" = "%+"
    "CtrlShift" = "^+"
    "AltCtrlShift" = "%^+"
}

# Prepara a tecla com modificador
$teclaComModificador = if ($Modificador -ne "Normal") { 
    $modificadoresMap[$Modificador] + $Tecla 
} else { 
    $Tecla 
}

# Função para obter informação da janela ativa
function Get-InfoJanelaAtiva {
    try {
        $shell = New-Object -ComObject "Shell.Application"
        $janela = $shell.Windows() | Where-Object { $_.HWND -eq (Get-ForegroundWindow) } | Select-Object -First 1
        
        if ($janela) {
            return @{
                Titulo = $janela.LocationName
                URL = $janela.LocationURL
            }
        }
    } catch {}
    
    return @{ Titulo = (Get-Process | Where-Object { $_.MainWindowHandle -eq (Get-ForegroundWindow) }).MainWindowTitle; URL = $null }
}

# Função para obter a janela em primeiro plano (para compatibilidade)
function Get-ForegroundWindow {
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class Win32 {
        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();
        
        [DllImport("user32.dll", SetLastError = true)]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
        
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetForegroundWindow(IntPtr hWnd);
    }
"@
    return [Win32]::GetForegroundWindow()
}

# Função para focar em uma janela específica
function Set-FocusJanela {
    param([string]$TituloJanela)
    
    if (-not $TituloJanela) { return $false }
    
    try {
        $processos = Get-Process | Where-Object { 
            $_.MainWindowTitle -like "*$TituloJanela*" -and $_.MainWindowHandle -ne 0 
        }
        
        foreach ($proc in $processos) {
            $null = [Win32]::SetForegroundWindow($proc.MainWindowHandle)
            Start-Sleep -Milliseconds 100
            return $true
        }
    } catch {}
    
    return $false
}

# Handler para Ctrl+C
[Console]::TreatControlCAsInput = $false
$cancelHandler = {
    param($sender, $e)
    $global:parar = $true
    $e.Cancel = $true
}
[Console]::add_CancelKeyPress($cancelHandler)

# Função de logging melhorada
function Escrever-Log {
    param(
        [string]$mensagem,
        [string]$tipo = "INFO",
        [string]$cor = 'White'
    )
    
    $hora = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $linha = "[$hora][$tipo] $mensagem"
    
    # Escreve no console se não for modo silencioso
    if (-not $Silencioso) {
        switch ($tipo) {
            "ERRO"   { Write-Host $linha -ForegroundColor Red }
            "ALERTA" { Write-Host $linha -ForegroundColor Yellow }
            "SUCESSO" { Write-Host $linha -ForegroundColor Green }
            "INFO"   { Write-Host $linha -ForegroundColor $cor }
            "DEBUG"  { Write-Host $linha -ForegroundColor Gray }
        }
    }
    
    # Escreve no arquivo de log se especificado
    if ($LogArquivo -ne "") {
        try {
            # Cria diretório se não existir
            $diretorioLog = Split-Path $LogArquivo -Parent
            if ($diretorioLog -and -not (Test-Path $diretorioLog)) {
                New-Item -ItemType Directory -Path $diretorioLog -Force | Out-Null
            }
            
            Add-Content -Path $LogArquivo -Value $linha -Encoding UTF8
        } catch {
            # Se não conseguir escrever no arquivo, apenas continua
        }
    }
}

# Exibe informações iniciais
if (-not $Silencioso) {
    Write-Host "`n=== Auto Key Press v$VersaoScript ===" -ForegroundColor Cyan
    Write-Host "Tecla: $Tecla" -ForegroundColor White
    Write-Host "Modificador: $Modificador" -ForegroundColor White
    Write-Host "Comando completo: $teclaComModificador" -ForegroundColor White
    Write-Host "Intervalo: $Intervalo segundos" -ForegroundColor White
    Write-Host "Delay inicial: $DelayInicial segundos" -ForegroundColor White
    if ($JanelaAlvo) { Write-Host "Janela alvo: $JanelaAlvo" -ForegroundColor White }
    if ($ContadorMaximo -gt 0) { Write-Host "Máximo de execuções: $ContadorMaximo" -ForegroundColor White }
    Write-Host "Log: $(if($LogArquivo){$LogArquivo}else{'Nenhum'})" -ForegroundColor White
    Write-Host "`nPressione Ctrl+C para parar`n" -ForegroundColor Yellow
}

# Bloco principal de execução
try {
    # Delay inicial
    if ($DelayInicial -gt 0) {
        Escrever-Log -mensagem "Iniciando em $DelayInicial segundos..." -tipo "INFO" -cor "Cyan"
        $segundosRestantes = $DelayInicial
        while ($segundosRestantes -gt 0 -and -not $global:parar) {
            Start-Sleep -Seconds 1
            $segundosRestantes--
            if (-not $Silencioso -and $segundosRestantes -gt 0 -and $segundosRestantes % 5 -eq 0) {
                Write-Host "  Iniciando em $segundosRestantes segundos..." -ForegroundColor DarkCyan
            }
        }
    }
    
    $contador = 0
    $primeiraExecucao = $true
    
    while (-not $global:parar) {
        # Verifica limite de execuções
        if ($ContadorMaximo -gt 0 -and $contador -ge $ContadorMaximo) {
            Escrever-Log -mensagem "Limite de $ContadorMaximo execuções atingido" -tipo "INFO" -cor "Green"
            break
        }
        
        $contador++
        
        # Foca na janela alvo se especificada (apenas na primeira execução ou se configurado)
        if ($JanelaAlvo -and ($primeiraExecucao -or $Intervalo -gt 60)) {
            if (Set-FocusJanela -TituloJanela $JanelaAlvo) {
                Escrever-Log -mensagem "Janela focada: $JanelaAlvo" -tipo "INFO" -cor "Green"
                Start-Sleep -Milliseconds 500  # Aguarda a janela ganhar foco
            } else {
                Escrever-Log -mensagem "Não foi possível focar na janela: $JanelaAlvo" -tipo "ALERTA"
            }
            $primeiraExecucao = $false
        }
        
        # Obtém informações da janela ativa para log
        $infoJanela = Get-InfoJanelaAtiva
        $infoJanelaStr = if ($infoJanela.Titulo) { 
            " (Janela: '$($infoJanela.Titulo.Substring(0, [Math]::Min(50, $infoJanela.Titulo.Length)))')" 
        } else { "" }
        
        # Envia a tecla
        Escrever-Log -mensagem "Enviando: $teclaComModificador - Execução #$contador$infoJanelaStr" -tipo "INFO"
        
        try {
            [System.Windows.Forms.SendKeys]::SendWait($teclaComModificador)
            Escrever-Log -mensagem "Tecla enviada com sucesso" -tipo "SUCESSO"
        } catch {
            Escrever-Log -mensagem "Erro ao enviar tecla: $_" -tipo "ERRO"
        }
        
        # Aguarda o intervalo (com tratamento de Ctrl+C)
        if ($contador -lt $ContadorMaximo -or $ContadorMaximo -eq 0) {
            $segundosRestantes = $Intervalo
            $ultimoUpdate = Get-Date
            
            while ($segundosRestantes -gt 0 -and -not $global:parar) {
                Start-Sleep -Seconds 1
                $segundosRestantes--
                
                # Mostra contagem regressiva a cada 5 segundos (se não for silencioso)
                if (-not $Silencioso -and $segundosRestantes -gt 0 -and $segundosRestantes % 5 -eq 0) {
                    $tempoDecorrido = (Get-Date) - $DataInicio
                    Write-Host "  Próxima execução em $segundosRestantes segundos (Tempo total: $($tempoDecorrido.ToString('hh\:mm\:ss')))" -ForegroundColor DarkGray
                }
            }
            
            if (-not $global:parar -and $segundosRestantes -eq 0) {
                Escrever-Log -mensagem "Aguardando próximo ciclo..." -tipo "DEBUG"
            }
        }
    }
}
catch {
    Escrever-Log -mensagem "Exceção inesperada: $_" -tipo "ERRO"
}
finally {
    # Remove handler para evitar vazamento de memória
    try { [Console]::remove_CancelKeyPress($cancelHandler) } catch {}
    
    # Estatísticas finais
    $tempoTotal = (Get-Date) - $DataInicio
    $tempoTotalStr = $tempoTotal.ToString('dd\.hh\:mm\:ss')
    
    Escrever-Log -mensagem "========================================" -tipo "INFO"
    Escrever-Log -mensagem "SCRIPT FINALIZADO" -tipo "INFO" -cor "Cyan"
    Escrever-Log -mensagem "Total de execuções: $contador" -tipo "INFO"
    Escrever-Log -mensagem "Tempo total: $tempoTotalStr" -tipo "INFO"
    Escrever-Log -mensagem "Tecla enviada: $teclaComModificador" -tipo "INFO"
    Escrever-Log -mensagem "Intervalo médio: $(if($contador -gt 1){[math]::Round($tempoTotal.TotalSeconds/($contador-1), 2)}else{0}) segundos" -tipo "INFO"
    
    if ($LogArquivo -ne "") {
        Escrever-Log -mensagem "Log salvo em: $LogArquivo" -tipo "INFO"
    }
    
    Escrever-Log -mensagem "========================================" -tipo "INFO"
    
    # Aguarda um pouco antes de fechar (para permitir leitura das informações)
    if (-not $Silencioso) {
        Start-Sleep -Seconds 2
    }
}
