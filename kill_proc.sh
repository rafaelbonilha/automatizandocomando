#
# Script em Bash o processo travado e salva a atividade em arquivo txt
#
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x kill_proc.sh
#
# 2-) Instale as dependencias, caso deseje enviar notificacao
#  Debian.:
#  sudo apt install  notify-send
#
#  RHEL/CentOS/Fedora.:
#  sudo dnf install notify-send ou
#  sudo yum install notify-send (CentOS)
#
# 3-) Como usar.:
#
# Uso Basico.:
# ./kill_proc.sh
#
# Padroes Usados.:
#
# Processos rodando a mais de 2 horas sao considerados suspeitos 
# Processos usando mais de 80% de CPU 
# Processos usando mais de 500MB de RAM
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab
#
#!/bin/bash

# Configuracoes
LOG_DIR="$HOME/GestaoProcessos"
LOG_FILE="$LOG_DIR/EncerrarProcessos_$(date +'%Y-%m-%d').log"
LIMITE_TEMPO_HORAS=2
LIMITE_CPU_PERCENT=80
LIMITE_MEMORIA_MB=500

# Criar diretorio de log
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi

# Funcoes
write_log() {
    local message="$1"
    local status="${2:-INFO}"
    local timestamp=$(date +'%d/%m/%Y %H:%M:%S')
    local log_message="$timestamp | $status | $message"
    
    echo "$log_message" >> "$LOG_FILE"
    
    case $status in
        "ERRO")
            echo -e "\e[31m$log_message\e[0m"
            ;;
        "SUCESSO")
            echo -e "\e[32m$log_message\e[0m"
            ;;
        "AVISO")
            echo -e "\e[33m$log_message\e[0m"
            ;;
        *)
            echo -e "\e[37m$log_message\e[0m"
            ;;
    esac
}

show_notification() {
    local title="$1"
    local message="$2"
    local type="${3:-Info}"
    
    # Tenta diferentes metodos de notificacao
    if command -v notify-send &> /dev/null; then
        case $type in
            "Info")
                notify-send -i info "$title" "$message"
                ;;
            "Warning")
                notify-send -i warning "$title" "$message"
                ;;
            "Error")
                notify-send -i error "$title" "$message"
                ;;
        esac
    elif command -v zenity &> /dev/null; then
        zenity --info --title="$title" --text="$message" &> /dev/null &
    fi
}

get_process_info() {
    local pid="$1"
    
    if [ -d "/proc/$pid" ] && [ "$pid" != "1" ]; then
        local name=$(cat /proc/$pid/comm 2>/dev/null)
        local cpu=$(ps -p $pid -o %cpu --no-headers 2>/dev/null | tr -d ' ')
        local mem=$(ps -p $pid -o rss --no-headers 2>/dev/null | tr -d ' ')
        local mem_mb=$((mem / 1024))
        local start_time=$(ps -p $pid -o lstart --no-headers 2>/dev/null)
        local etime=$(ps -p $pid -o etime --no-headers 2>/dev/null)
        local stat=$(cat /proc/$pid/stat 2>/dev/null | cut -d' ' -f3)
        local responding="true"
        
        [ "$stat" = "D" ] || [ "$stat" = "T" ] || [ "$stat" = "Z" ] && responding="false"
        
        echo "$pid:$name:$cpu:$mem_mb:$start_time:$etime:$responding"
    fi
}

test_process_hung() {
    local pid="$1"
    local process_name="$2"
    local criterios=()
    
    if [ ! -d "/proc/$pid" ]; then
        return 1
    fi
    
    # Verifica se processo esta respondendo
    local stat=$(cat /proc/$pid/stat 2>/dev/null | cut -d' ' -f3)
    if [ "$stat" = "D" ] || [ "$stat" = "T" ] || [ "$stat" = "Z" ]; then
        criterios+=("Nao respondendo")
    fi
    
    # Verifica tempo de execucao
    local start_time=$(cat /proc/$pid/stat 2>/dev/null | cut -d' ' -f22)
    local now=$(date +%s)
    local uptime=$(cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1)
    local process_start=$((now - uptime + start_time/100))
    local running_hours=$(( (now - process_start) / 3600 ))
    
    if [ $running_hours -gt $LIMITE_TEMPO_HORAS ]; then
        criterios+=("Executando a $running_hours horas")
    fi
    
    # Verifica uso de CPU
    local cpu=$(ps -p $pid -o %cpu --no-headers 2>/dev/null | tr -d ' ' | cut -d'.' -f1)
    if [ -n "$cpu" ] && [ $cpu -gt $LIMITE_CPU_PERCENT ]; then
        criterios+=("CPU em $cpu%")
    fi
    
    # Verifica uso de memoria
    local mem=$(ps -p $pid -o rss --no-headers 2>/dev/null | tr -d ' ')
    local mem_mb=$((mem / 1024))
    if [ $mem_mb -gt $LIMITE_MEMORIA_MB ]; then
        criterios+=("Memoria em ${mem_mb}MB")
    fi
    
    if [ ${#criterios[@]} -gt 0 ]; then
        printf '%s\n' "${criterios[@]}"
        return 0
    fi
    
    return 1
}

stop_stuck_process() {
    local pid="$1"
    local reason="$2"
    local force="$3"
    
    if [ ! -d "/proc/$pid" ]; then
        write_log "Processo $pid nao encontrado" "ERRO"
        return 1
    fi
    
    local process_name=$(cat /proc/$pid/comm 2>/dev/null)
    
    if [ "$force" = "force" ]; then
        kill -9 $pid 2>/dev/null
        write_log "Processo $process_name (PID: $pid) encerrado a forca. Motivo: $reason" "SUCESSO"
        show_notification "Processo Encerrado" "Processo $process_name (PID: $pid) foi encerrado forcadamente" "Warning"
        return 0
    else
        kill $pid 2>/dev/null
        sleep 3
        
        if [ ! -d "/proc/$pid" ]; then
            write_log "Processo $process_name (PID: $pid) encerrado graciosamente. Motivo: $reason" "SUCESSO"
            return 0
        else
            kill -9 $pid 2>/dev/null
            write_log "Processo $process_name (PID: $pid) encerrado a forca apos falha na tentativa graciosa. Motivo: $reason" "SUCESSO"
            return 0
        fi
    fi
}

get_suspicious_processes() {
    local processos_suspeitos=()
    
    for pid in $(ls /proc | grep -E '^[0-9]+$' | sort -n); do
        if [ -d "/proc/$pid" ] && [ "$pid" != "1" ] && [ "$pid" != "2" ]; then
            local process_name=$(cat /proc/$pid/comm 2>/dev/null)
            local criterios=$(test_process_hung $pid "$process_name")
            
            if [ -n "$criterios" ]; then
                local cpu=$(ps -p $pid -o %cpu --no-headers 2>/dev/null | tr -d ' ' | cut -d'.' -f1)
                local mem=$(ps -p $pid -o rss --no-headers 2>/dev/null | tr -d ' ')
                local mem_mb=$((mem / 1024))
                local etime=$(ps -p $pid -o etime --no-headers 2>/dev/null | tr -d ' ')
                local stat=$(cat /proc/$pid/stat 2>/dev/null | cut -d' ' -f3)
                local responding="Sim"
                
                [ "$stat" = "D" ] || [ "$stat" = "T" ] || [ "$stat" = "Z" ] && responding="Nao"
                
                processos_suspeitos+=("$pid:$process_name:$cpu:$mem_mb:$etime:$responding:$criterios")
            fi
        fi
    done
    
    printf '%s\n' "${processos_suspeitos[@]}"
}

clear

# Cabecalho
echo -e "\e[36m=========================================\e[0m"
echo -e "\e[36m        GESTAO DE PROCESSOS - ENCERRAR TRAVADOS     \e[0m"
echo -e "\e[36m=========================================\e[0m"
echo ""

write_log "=== INICIO DA GESTAO DE PROCESSOS ==="

# Menu principal
while true; do
    echo ""
    echo -e "\e[33mOPCOES DISPONIVEIS:\e[0m"
    echo -e "\e[37m1. Listar processos suspeitos (travados)\e[0m"
    echo -e "\e[37m2. Listar todos os processos com consumo alto\e[0m"
    echo -e "\e[37m3. Encerrar processo especifico por PID\e[0m"
    echo -e "\e[37m4. Encerrar processo especifico por nome\e[0m"
    echo -e "\e[37m5. Encerrar todos os processos suspeitos automaticamente\e[0m"
    echo -e "\e[37m6. Forcar encerramento de processo\e[0m"
    echo -e "\e[37m0. Sair\e[0m"
    
    echo -ne "\n\e[36mEscolha uma opcao: \e[0m"
    read opcao
    
    case $opcao in
        1)
            echo ""
            echo -e "\e[33mPROCESSOS SUSPEITOS (TRAVADOS):\e[0m"
            
            suspeitos=$(get_suspicious_processes)
            
            if [ -z "$suspeitos" ]; then
                echo -e "\e[32mNenhum processo suspeito encontrado.\e[0m"
                write_log "Nenhum processo suspeito encontrado" "INFO"
            else
                echo -e "PID\tNOME\t\tCPU\tMEM(MB)\tTEMPO\tRESP\tCRITERIOS"
                echo "----------------------------------------------------------------"
                echo "$suspeitos" | while IFS=: read pid name cpu mem etime resp criterios; do
                    printf "%s\t%-10s\t%s\t%s\t%s\t%s\t%s\n" "$pid" "$name" "$cpu" "$mem" "$etime" "$resp" "$criterios"
                done
                
                count=$(echo "$suspeitos" | wc -l)
                write_log "Encontrados $count processos suspeitos" "AVISO"
                
                echo -ne "\n\e[36mDeseja encerrar estes processos? (S/N): \e[0m"
                read encerrar
                if [ "$encerrar" = "S" ] || [ "$encerrar" = "s" ]; then
                    echo "$suspeitos" | while IFS=: read pid name cpu mem etime resp criterios; do
                        stop_stuck_process "$pid" "$criterios"
                        sleep 0.5
                    done
                fi
            fi
            ;;
            
        2)
            echo ""
            echo -e "\e[33mTOP PROCESSOS POR CONSUMO:\e[0m"
            
            echo -e "PID\tNOME\t\tCPU\tMEM(MB)\tTHREADS\tRESP"
            echo "--------------------------------------------------------"
            ps aux --sort=-%cpu | head -20 | tail -n +2 | while read user pid cpu mem vsz rss tty stat start time command; do
                mem_mb=$((rss / 1024))
                threads=$(ls /proc/$pid/task 2>/dev/null | wc -l)
                responding="Sim"
                [ "$stat" = "D" ] || [ "$stat" = "T" ] || [ "$stat" = "Z" ] && responding="Nao"
                printf "%s\t%-10s\t%s\t%s\t%s\t%s\n" "$pid" "$(basename $command)" "$cpu" "$mem_mb" "$threads" "$responding"
            done
            
            write_log "Listados top 20 processos por consumo" "INFO"
            ;;
            
        3)
            echo -ne "\e[36mDigite o PID do processo: \e[0m"
            read pid
            if [[ "$pid" =~ ^[0-9]+$ ]] && [ -d "/proc/$pid" ]; then
                echo ""
                echo -e "\e[33mINFORMACOES DO PROCESSO:\e[0m"
                echo "PID: $pid"
                echo "Nome: $(cat /proc/$pid/comm 2>/dev/null)"
                echo "CPU: $(ps -p $pid -o %cpu --no-headers 2>/dev | tr -d ' ')%"
                mem=$(ps -p $pid -o rss --no-headers 2>/dev/null | tr -d ' ')
                echo "Memoria: $((mem / 1024)) MB"
                echo "Tempo de execucao: $(ps -p $pid -o etime --no-headers 2>/dev | tr -d ' ')"
                echo ""
                
                echo -ne "\e[36mDeseja encerrar este processo? (S/N): \e[0m"
                read confirm
                if [ "$confirm" = "S" ] || [ "$confirm" = "s" ]; then
                    echo -ne "\e[36mForcar encerramento? (S/N): \e[0m"
                    read forcar
                    if [ "$forcar" = "S" ] || [ "$forcar" = "s" ]; then
                        stop_stuck_process "$pid" "Encerramento manual forcado" "force"
                    else
                        stop_stuck_process "$pid" "Encerramento manual"
                    fi
                fi
            else
                echo -e "\e[31mProcesso nao encontrado.\e[0m"
            fi
            ;;
            
        4)
            echo -ne "\e[36mDigite o nome do processo (ex: firefox): \e[0m"
            read nome
            
            processos=$(pgrep -f "$nome" 2>/dev/null)
            
            if [ -n "$processos" ]; then
                echo ""
                echo -e "\e[33mPROCESSOS ENCONTRADOS:\e[0m"
                echo -e "PID\tNOME\t\tCPU\tMEM(MB)"
                echo "----------------------------------------"
                for pid in $processos; do
                    name=$(cat /proc/$pid/comm 2>/dev/null)
                    cpu=$(ps -p $pid -o %cpu --no-headers 2>/dev/null | tr -d ' ')
                    mem=$(ps -p $pid -o rss --no-headers 2>/dev/null | tr -d ' ')
                    mem_mb=$((mem / 1024))
                    printf "%s\t%-10s\t%s\t%s\n" "$pid" "$name" "$cpu" "$mem_mb"
                done
                
                echo -ne "\n\e[36mEncerrar todos os processos com este nome? (S/N): \e[0m"
                read encerrarTodos
                if [ "$encerrarTodos" = "S" ] || [ "$encerrarTodos" = "s" ]; then
                    for pid in $processos; do
                        stop_stuck_process "$pid" "Encerramento por nome: $nome"
                    done
                fi
            else
                echo -e "\e[31mNenhum processo encontrado com o nome: $nome\e[0m"
            fi
            ;;
            
        5)
            suspeitos=$(get_suspicious_processes)
            
            if [ -z "$suspeitos" ]; then
                echo -e "\e[32mNenhum processo suspeito encontrado.\e[0m"
            else
                echo ""
                echo -e "\e[33mPROCESSOS QUE SERAO ENCERRADOS:\e[0m"
                count=$(echo "$suspeitos" | wc -l)
                echo "$suspeitos" | while IFS=: read pid name cpu mem etime resp criterios; do
                    echo "PID: $pid - Nome: $name - Criterios: $criterios"
                done
                
                echo -ne "\n\e[36mConfirmar encerramento automatico de $count processos? (S/N): \e[0m"
                read confirm
                if [ "$confirm" = "S" ] || [ "$confirm" = "s" ]; then
                    echo "$suspeitos" | while IFS=: read pid name cpu mem etime resp criterios; do
                        stop_stuck_process "$pid" "Encerramento automatico: $criterios"
                        sleep 0.5
                    done
                    write_log "Encerramento automatico concluido: $count processos" "SUCESSO"
                fi
            fi
            ;;
            
        6)
            echo -ne "\e[36mDigite o PID do processo para forcar encerramento: \e[0m"
            read pid
            if [[ "$pid" =~ ^[0-9]+$ ]] && [ -d "/proc/$pid" ]; then
                name=$(cat /proc/$pid/comm 2>/dev/null)
                echo -ne "\e[31mFORCAR encerramento do processo $name (PID: $pid)? (S/N): \e[0m"
                read confirm
                if [ "$confirm" = "S" ] || [ "$confirm" = "s" ]; then
                    stop_stuck_process "$pid" "Forcado manualmente" "force"
                fi
            else
                echo -e "\e[31mProcesso nao encontrado.\e[0m"
            fi
            ;;
            
        0)
            break
            ;;
    esac
    
    if [ "$opcao" != "0" ]; then
        echo ""
        echo -e "\e[37mPressione Enter para continuar...\e[0m"
        read
        clear
        
        # Cabecalho
        echo -e "\e[36m=========================================\e[0m"
        echo -e "\e[36m        GESTAO DE PROCESSOS - ENCERRAR TRAVADOS     \e[0m"
        echo -e "\e[36m=========================================\e[0m"
    fi
done

write_log "=== FIM DA GESTAO DE PROCESSOS ==="

echo ""
echo -e "\e[36m=========================================\e[0m"
echo -e "\e[36m           FERRAMENTA ENCERRADA           \e[0m"
echo -e "\e[36m=========================================\e[0m"
echo ""
echo -e "\e[32mLog das operacoes salvo em: $LOG_FILE\e[0m"
echo ""

# Resumo do log
if [ -f "$LOG_FILE" ]; then
    echo -e "\e[33mUltimas operacoes realizadas:\e[0m"
    echo ""
    
    tail -10 "$LOG_FILE" | while IFS= read -r linha; do
        if [[ "$linha" == *"SUCESSO"* ]]; then
            echo -e "\e[32m$linha\e[0m"
        elif [[ "$linha" == *"ERRO"* ]]; then
            echo -e "\e[31m$linha\e[0m"
        elif [[ "$linha" == *"AVISO"* ]]; then
            echo -e "\e[33m$linha\e[0m"
        else
            echo -e "\e[37m$linha\e[0m"
        fi
    done
fi

echo ""
echo -e "\e[37mPressione Enter para sair...\e[0m"
read
