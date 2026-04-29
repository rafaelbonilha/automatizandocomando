#
# Script em Bash que fecha a calculadora e registra a atividade em um arquivo txt
#
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x close_calc.sh
#
#
# 2-) Como usar.:
#
# Uso Basico.:
# ./close_calc.sh
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab
#
#!/bin/bash

# Configs
LOG_DIR="$HOME/KillCalc"
LOG_FILE="$LOG_DIR/KillCalc_$(date +'%Y-%m-%d').log"

# Cria dir de log se necessario
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi

# Funcs
write_log() {
    local message="$1"
    local status="${2:-INFO}"
    local timestamp=$(date +'%d/%m/%Y %H:%M:%S')
    local log_message="$timestamp | $status | $message"
    
    echo "$log_message" >> "$LOG_FILE"
    
    # Cores para output
    case "$status" in
        "ERRO")
            echo -e "\033[31m$log_message\033[0m"
            ;;
        "SUCESSO")
            echo -e "\033[32m$log_message\033[0m"
            ;;
        "AVISO")
            echo -e "\033[33m$log_message\033[0m"
            ;;
        *)
            echo -e "\033[90m$log_message\033[0m"
            ;;
    esac
}

show_header() {
    local line=$(printf '%0.s=' {1..55})
    echo ""
    echo -e "\033[36m$line\033[0m"
    echo -e "\033[36m  ENCERRAMENTO DA CALCULADORA\033[0m"
    echo -e "\033[36m$line\033[0m"
    echo ""
}

get_calc_processes() {
    # Nomes de processo conhecidos de calculadoras no Linux
    echo "gnome-calculator"
    echo "kcalc"
    echo "calculator"
    echo "qalculate-gtk"
    echo "galculator"
    echo "mate-calc"
}

find_calc() {
    local encontrados=""
    local nomes=$(get_calc_processes)
    
    for nome in $nomes; do
        local pids=$(pgrep -x "$nome" 2>/dev/null)
        for pid in $pids; do
            if [ -n "$pid" ]; then
                local ram=$(ps -o rss= -p $pid 2>/dev/null | awk '{print $1}')
                if [ -n "$ram" ]; then
                    ram_mb=$(echo "scale=2; $ram / 1024" | bc)
                    encontrados="$encontrados$pid|$nome|$ram_mb\n"
                fi
            fi
        done
    done
    
    echo -e "$encontrados" | sed '/^$/d'
}

show_calc_status() {
    local processos="$1"
    local line=$(printf '%0.s=' {1..55})
    local count=0
    
    printf "  %-10s %-30s %s\n" "PID" "Processo" "RAM (MB)"
    printf "  %s\n" "--------------------------------------------------"
    
    if [ -n "$processos" ]; then
        echo "$processos" | while IFS='|' read pid nome ram; do
            if [ -n "$pid" ]; then
                printf "  %-10s %-30s %s\n" "$pid" "$nome" "$ram"
                ((count++))
            fi
        done
    fi
    
    count=$(echo "$processos" | grep -c '|' 2>/dev/null || echo "0")
    echo ""
    echo -e "  Total encontrado: $count processo(s)"
    echo -e "\033[36m$line\033[0m"
    echo ""
}

stop_calc() {
    local processos="$1"
    local encerrados=0
    local falhas=0
    
    echo "$processos" | while IFS='|' read pid nome ram; do
        if [ -n "$pid" ]; then
            write_log "Encerrando processo: $nome (PID: $pid)" "INFO"
            
            if kill -9 "$pid" 2>/dev/null; then
                echo -e "  \033[32mProcesso $nome (PID: $pid) encerrado com sucesso.\033[0m"
                write_log "Processo $nome (PID: $pid) encerrado com sucesso" "SUCESSO"
                ((encerrados++))
            else
                echo -e "  \033[31mFalha ao encerrar $nome (PID: $pid)\033[0m"
                write_log "Falha ao encerrar $nome (PID: $pid)" "ERRO"
                ((falhas++))
            fi
        fi
    done
    
    # Aguarda processos filhos terminarem
    wait
    
    echo ""
    echo -e "  \033[36mResultado: $encerrados encerrado(s) | $falhas falha(s)\033[0m"
    write_log "Resultado final: $encerrados encerrado(s), $falhas falha(s)" "INFO"
}

# INICIO
main() {
    show_header
    write_log "=== INICIO DO ENCERRAMENTO DA CALCULADORA ===" "INFO"
    
    # Passo 1: Busca processos
    local encontrados=$(find_calc)
    
    if [ -z "$encontrados" ]; then
        echo -e "  \033[33mNenhum processo de calculadora encontrado em execucao.\033[0m"
        echo ""
        write_log "Nenhum processo de calculadora encontrado" "AVISO"
    else
        # Passo 2: Exibe processos encontrados
        echo -e "  \033[37mProcessos de calculadora encontrados:\033[0m"
        show_calc_status "$encontrados"
        
        # Passo 3: Confirmacao de usuario
        read -p "  Deseja encerrar todos os processos listados? (S/N) " confirmar
        if [[ "$confirmar" != "S" && "$confirmar" != "s" ]]; then
            write_log "Operacao cancelada pelo usuario" "AVISO"
            echo -e "  \033[33mOperacao cancelada.\033[0m"
            echo ""
            exit 0
        fi
        
        echo ""
        
        # Passo 4: Encerra os processos
        stop_calc "$encontrados"
    fi
    
    write_log "=== FIM DO ENCERRAMENTO DA CALCULADORA ===" "INFO"
    echo ""
    echo -e "  \033[32mLog salvo em: $LOG_FILE\033[0m"
    echo ""
    
    exit 0
}

# Executa func principal com tratamento de erros
if ! main; then
    error_msg="Erro durante a execução: linha ${BASH_LINENO[0]}"
    write_log "$error_msg" "ERRO"
    echo -e "\033[31mERRO: $error_msg\033[0m"
    exit 1
fi
