<#
.SYNOPSIS
Encerra o processo travado e salva a atividade em arquivo txt.

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\kill_process.ps1 ou .\kill_process.ps1

Padroes Usados.:

 Processos rodando a mais de 2 horas sao considerados suspeitos 
 Processos usando mais de 80% de CPU 
 Processos usando mais de 500MB de RAM
 
 Importante.: Esses valores acima podem ser alterados

Caso de Uso.:

Basico.: .\kill_process.ps1 - Encerra os processos travados  e salva a atividade em um arquivo txt.

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab e use S e N em maíuscula para encerrar o script.

#>

Add-Type -AssemblyName System.Windows.Forms

# Configuracoes
$logDir = "$env:USERPROFILE\GestaoProcessos"
$logFile = "$logDir\EncerrarProcessos_$(Get-Date -Format 'yyyy-MM-dd').log"
$limiteTempoHoras = 2 
$limiteCPUPercent = 80 
$limiteMemoriaMB = 500 

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
        "Info" { $notify.Icon = [System.Drawing.SystemIcons]::Information }
        "Warning" { $notify.Icon = [System.Drawing.SystemIcons]::Warning }
        "Error" { $notify.Icon = [System.Drawing.SystemIcons]::Error }
    }
    
    $notify.BalloonTipTitle = $Title
    $notify.BalloonTipText = $Message
    $notify.Visible = $true
    $notify.ShowBalloonTip(10000)
}

function Get-ProcessInfo {
    param([int]$ProcessId)
    
    try {
        $process = Get-Process -Id $ProcessId -ErrorAction Stop
        $timespan = (Get-Date) - $process.StartTime
        $cpu = Get-Counter "\Process($($process.ProcessName))\*" -ErrorAction SilentlyContinue
        
        return [PSCustomObject]@{
            Id = $process.Id
            Name = $process.ProcessName
            CPU = $process.CPU
            MemoryMB = [math]::Round($process.WorkingSet / 1MB, 2)
            StartTime = $process.StartTime
            RunningTime = $timespan
            HasWindow = $process.MainWindowHandle -ne 0
            Responding = $process.Responding
        }
    } catch {
        return $null
    }
}

function Test-ProcessHung {
    param(
        [int]$ProcessId,
        [string]$ProcessName
    )
    
    try {
        $process = Get-Process -Id $ProcessId -ErrorAction Stop
        
        # Criterios para considerar um processo travado.:
        $criterios = @()
        
        # 1. Nao responde (Not Responding)
        if (-not $process.Responding) {
            $criterios += "Nao respondendo"
        }
        
        # 2. Rodando a mais de 2 horas (esse tempo pode ser alterado)
        $runningTime = (Get-Date) - $process.StartTime
        if ($runningTime.TotalHours -gt $limiteTempoHoras) {
            $criterios += "Executando a $([math]::Round($runningTime.TotalHours, 1)) horas"
        }
        
        # 3. Alto uso de CPU
        if ($process.CPU -gt $limiteCPUPercent) {
            $criterios += "CPU em $($process.CPU)%"
        }
        
        # 4. Alto uso de memoria
        $memoriaMB = $process.WorkingSet / 1MB
        if ($memoriaMB -gt $limiteMemoriaMB) {
            $criterios += "Memoria em $([math]::Round($memoriaMB, 0))MB"
        }
        
        return $criterios
    } catch {
        return $null
    }
}

function Stop-StuckProcess {
    param(
        [int]$ProcessId,
        [string]$Reason,
        [switch]$Force
    )
    
    try {
        $process = Get-Process -Id $ProcessId -ErrorAction Stop
        $processName = $process.ProcessName
        
        if ($Force) {
            # Forca o encerramento 
            $process.Kill()
            Write-Log "Processo $processName (PID: $ProcessId) encerrado a forca. Motivo: $Reason" "SUCESSO"
            Show-Notification -Title "Processo Encerrado" -Message "Processo $processName (PID: $ProcessId) foi encerrado forcadamente" -Type "Warning"
            return $true
        } else {
            # Tentativa normal
            if ($process.CloseMainWindow()) {
                Start-Sleep -Seconds 3
                if (-not (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) {
                    Write-Log "Processo $processName (PID: $ProcessId) encerrado graciosamente. Motivo: $Reason" "SUCESSO"
                    return $true
                }
            }
            
            # Se nao fechou, tenta forcado
            $process.Kill()
            Write-Log "Processo $processName (PID: $ProcessId) encerrado a forca apos falha na tentativa graciosa. Motivo: $Reason" "SUCESSO"
            return $true
        }
    } catch {
        Write-Log "Erro ao encerrar processo ID $ProcessId : $_" "ERRO"
        return $false
    }
}

function Get-SuspiciousProcesses {
    $processosSuspeitos = @()
    
    $processes = Get-Process | Where-Object { $_.Id -ne 0 -and $_.ProcessName -notin @('Idle', 'System') }
    
    foreach ($proc in $processes) {
        $criterios = Test-ProcessHung -ProcessId $proc.Id
        
        if ($criterios) {
            $processosSuspeitos += [PSCustomObject]@{
                PID = $proc.Id
                Nome = $proc.ProcessName
                CPU = [math]::Round($proc.CPU, 2)
                MemoriaMB = [math]::Round($proc.WorkingSet / 1MB, 2)
                TempoExecucao = (Get-Date) - $proc.StartTime
                Criterios = $criterios -join ', '
                Respondendo = $proc.Responding
            }
        }
    }
    
    return $processosSuspeitos | Sort-Object -Property CPU -Descending
}

Clear-Host

# Cabecalho
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "        GESTAO DE PROCESSOS - ENCERRAR TRAVADOS     " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "=== INICIO DA GESTAO DE PROCESSOS ==="

# Menu principal
do {
    Write-Host ""
    Write-Host "OPCOES DISPONIVEIS:" -ForegroundColor Yellow
    Write-Host "1. Listar processos suspeitos (travados)" -ForegroundColor White
    Write-Host "2. Listar todos os processos com consumo alto" -ForegroundColor White
    Write-Host "3. Encerrar processo especifico por PID" -ForegroundColor White
    Write-Host "4. Encerrar processo especifico por nome" -ForegroundColor White
    Write-Host "5. Encerrar todos os processos suspeitos automaticamente" -ForegroundColor White
    Write-Host "6. Forcar encerramento de processo" -ForegroundColor White
    Write-Host "0. Sair" -ForegroundColor White
    
    $opcao = Read-Host "`nEscolha uma opcao"
    
    switch ($opcao) {
        "1" {
            Write-Host ""
            Write-Host "PROCESSOS SUSPEITOS (TRAVADOS):" -ForegroundColor Yellow
            
            $suspeitos = Get-SuspiciousProcesses
            
            if ($suspeitos.Count -eq 0) {
                Write-Host "Nenhum processo suspeito encontrado." -ForegroundColor Green
                Write-Log "Nenhum processo suspeito encontrado" "INFO"
            } else {
                $suspeitos | Format-Table PID, Nome, CPU, MemoriaMB, TempoExecucao, Respondendo, Criterios -AutoSize
                Write-Log "Encontrados $($suspeitos.Count) processos suspeitos" "AVISO"
                
                $encerrar = Read-Host "`nDeseja encerrar estes processos? (S/N)"
                if ($encerrar -eq "S" -or $encerrar -eq "s") {
                    foreach ($proc in $suspeitos) {
                        Stop-StuckProcess -ProcessId $proc.PID -Reason $proc.Criterios
                        Start-Sleep -Milliseconds 500
                    }
                }
            }
        }
        
        "2" {
            Write-Host ""
            Write-Host "TOP PROCESSOS POR CONSUMO:" -ForegroundColor Yellow
            
            $topProcessos = Get-Process | Where-Object { $_.Id -ne 0 } | 
                Select-Object Id, ProcessName, 
                    @{Name="CPU";Expression={[math]::Round($_.CPU, 2)}},
                    @{Name="MemoriaMB";Expression={[math]::Round($_.WorkingSet / 1MB, 2)}},
                    @{Name="Threads";Expression={$_.Threads.Count}},
                    @{Name="Respondendo";Expression={$_.Responding}} |
                Sort-Object -Property CPU -Descending | Select-Object -First 20
            
            $topProcessos | Format-Table Id, ProcessName, CPU, MemoriaMB, Threads, Respondendo -AutoSize
            Write-Log "Listados top 20 processos por consumo" "INFO"
        }
        
        "3" {
            $pid = Read-Host "Digite o PID do processo"
            if ($pid -match '^\d+$') {
                $info = Get-ProcessInfo -ProcessId $pid
                if ($info) {
                    Write-Host ""
                    Write-Host "INFORMACOES DO PROCESSO:" -ForegroundColor Yellow
                    $info | Format-List
                    
                    $confirm = Read-Host "`nDeseja encerrar este processo? (S/N)"
                    if ($confirm -eq "S" -or $confirm -eq "s") {
                        $forcar = Read-Host "Forcar encerramento? (S/N)"
                        if ($forcar -eq "S" -or $forcar -eq "s") {
                            Stop-StuckProcess -ProcessId $pid -Reason "Encerramento manual forcado" -Force
                        } else {
                            Stop-StuckProcess -ProcessId $pid -Reason "Encerramento manual"
                        }
                    }
                } else {
                    Write-Host "Processo nao encontrado." -ForegroundColor Red
                }
            } else {
                Write-Host "PID invalido." -ForegroundColor Red
            }
        }
        
        "4" {
            $nome = Read-Host "Digite o nome do processo (ex: notepad)"
            $processos = Get-Process -Name "$nome*" -ErrorAction SilentlyContinue
            
            if ($processos) {
                Write-Host ""
                Write-Host "PROCESSOS ENCONTRADOS:" -ForegroundColor Yellow
                $processos | Select-Object Id, ProcessName, 
                    @{Name="CPU";Expression={[math]::Round($_.CPU, 2)}},
                    @{Name="MemoriaMB";Expression={[math]::Round($_.WorkingSet / 1MB, 2)}} |
                    Format-Table -AutoSize
                
                $encerrarTodos = Read-Host "`nEncerrar todos os processos com este nome? (S/N)"
                if ($encerrarTodos -eq "S" -or $encerrarTodos -eq "s") {
                    foreach ($proc in $processos) {
                        Stop-StuckProcess -ProcessId $proc.Id -Reason "Encerramento por nome: $nome"
                    }
                }
            } else {
                Write-Host "Nenhum processo encontrado com o nome: $nome" -ForegroundColor Red
            }
        }
        
        "5" {
            $suspeitos = Get-SuspiciousProcesses
            
            if ($suspeitos.Count -eq 0) {
                Write-Host "Nenhum processo suspeito encontrado." -ForegroundColor Green
            } else {
                Write-Host ""
                Write-Host "PROCESSOS QUE SERAO ENCERRADOS:" -ForegroundColor Yellow
                $suspeitos | Format-Table PID, Nome, Criterios -AutoSize
                
                $confirm = Read-Host "`nConfirmar encerramento automatico de $($suspeitos.Count) processos? (S/N)"
                if ($confirm -eq "S" -or $confirm -eq "s") {
                    foreach ($proc in $suspeitos) {
                        Stop-StuckProcess -ProcessId $proc.PID -Reason "Encerramento automatico: $($proc.Criterios)"
                        Start-Sleep -Milliseconds 500
                    }
                    Write-Log "Encerramento automatico concluido: $($suspeitos.Count) processos" "SUCESSO"
                }
            }
        }
        
        "6" {
            $pid = Read-Host "Digite o PID do processo para forcar encerramento"
            if ($pid -match '^\d+$') {
                $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
                if ($process) {
                    $confirm = Read-Host "FORCAR encerramento do processo $($process.ProcessName) (PID: $pid)? (S/N)"
                    if ($confirm -eq "S" -or $confirm -eq "s") {
                        Stop-StuckProcess -ProcessId $pid -Reason "Forcado manualmente" -Force
                    }
                } else {
                    Write-Host "Processo nao encontrado." -ForegroundColor Red
                }
            }
        }
    }
    
    if ($opcao -ne "0") {
        Write-Host ""
        Write-Host "Pressione qualquer tecla para continuar..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-Host
        
        # Cabecalho
        Write-Host "=========================================" -ForegroundColor Cyan
        Write-Host "        GESTAO DE PROCESSOS - ENCERRAR TRAVADOS     " -ForegroundColor Cyan
        Write-Host "=========================================" -ForegroundColor Cyan
    }
    
} while ($opcao -ne "0")

Write-Log "=== FIM DA GESTAO DE PROCESSOS ==="

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "           FERRAMENTA ENCERRADA           " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Log das operacoes salvo em: $logFile" -ForegroundColor Green
Write-Host ""

# Resumo do log
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