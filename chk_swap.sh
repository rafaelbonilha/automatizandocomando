#
# Script em Bash que muda o diretorio automaticamente
#
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x chk_swap.sh
#
#
# 2-) Como usar.:
#
# Uso Basico.:
# ./chk_swap.sh
#
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab
#
#!/bin/bash

# Configs de Log
LOG_DIR="$HOME/SwapMonitor"
LOG_FILE="$LOG_DIR/SwapMonitor_$(date '+%Y-%m-%d').log"
LIMITE_SWAP=75  # percentual de alerta
 
mkdir -p "$LOG_DIR"
 
# Cores

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'
 
# Funcs
 
write_log() {
    local message="$1"
    local status="${2:-INFO}"
    local timestamp
    timestamp=$(date '+%d/%m/%Y %H:%M:%S')
    local log_message="$timestamp | $status | $message"
 
    echo "$log_message" >> "$LOG_FILE"
 
    case "$status" in
        ERRO)    echo -e "${RED}${log_message}${NC}" ;;
        SUCESSO) echo -e "${GREEN}${log_message}${NC}" ;;
        AVISO)   echo -e "${YELLOW}${log_message}${NC}" ;;
        *)       echo -e "${GRAY}${log_message}${NC}" ;;
    esac
}
 
get_swap_info() {
    # Lê valores do /proc/meminfo em kB
    local total_kb usado_kb livre_kb
    total_kb=$(grep 'SwapTotal' /proc/meminfo | awk '{print $2}')
    livre_kb=$(grep 'SwapFree'  /proc/meminfo | awk '{print $2}')
    usado_kb=$(( total_kb - livre_kb ))
 
    # Converte para MB com 2 casas decimais
    SWAP_TOTAL_MB=$(awk "BEGIN {printf \"%.2f\", $total_kb/1024}")
    SWAP_USADO_MB=$(awk "BEGIN {printf \"%.2f\", $usado_kb/1024}")
    SWAP_LIVRE_MB=$(awk "BEGIN {printf \"%.2f\", $livre_kb/1024}")
 
    # Calcula percentual
    if [ "$total_kb" -gt 0 ]; then
        SWAP_PERCENT=$(awk "BEGIN {printf \"%.1f\", ($usado_kb/$total_kb)*100}")
    else
        SWAP_PERCENT="0.0"
    fi
 
    SWAP_PERCENT_INT=$(echo "$SWAP_PERCENT" | cut -d. -f1)
}
 
show_swap_status() {
    local line
    line=$(printf '=%.0s' {1..55})
 
    echo ""
    echo -e "${CYAN}${line}${NC}"
    echo -e "${CYAN}  MONITORAMENTO DE MEMORIA SWAP${NC}"
    echo -e "${CYAN}${line}${NC}"
    echo ""
    printf "${WHITE}  %-20s : %s MB${NC}\n" "Total"  "$SWAP_TOTAL_MB"
    printf "${WHITE}  %-20s : %s MB${NC}\n" "Usado"  "$SWAP_USADO_MB"
    printf "${WHITE}  %-20s : %s MB${NC}\n" "Livre"  "$SWAP_LIVRE_MB"
 
    # Cor do percentual conforme nivel de uso
    local cor_percent
    if [ "$SWAP_PERCENT_INT" -gt 90 ] 2>/dev/null; then
        cor_percent=$RED
    elif [ "$SWAP_PERCENT_INT" -gt 75 ] 2>/dev/null; then
        cor_percent=$YELLOW
    else
        cor_percent=$GREEN
    fi
 
    printf "${cor_percent}  %-20s : %s%%${NC}\n" "Uso atual"       "$SWAP_PERCENT"
    printf "${GRAY}  %-20s : %s%%${NC}\n"         "Limite de alerta" "$LIMITE_SWAP"
    echo ""
    echo -e "${CYAN}${line}${NC}"
}
 
# Exibe os top 5 processos por uso de memoria

show_top_processos() {
    echo ""
    echo -e "${YELLOW}  Top 5 processos por consumo de memoria:${NC}"
    echo ""
    printf "${WHITE}  %-8s %-25s %-10s${NC}\n" "PID" "PROCESSO" "RAM (MB)"
    echo "  $(printf '%.0s-' {1..45})"
 
    ps aux --sort=-%mem 2>/dev/null | awk 'NR>1 && NR<=6 {
        pid=$2
        mem_kb=$6
        cmd=$11
        n=split(cmd, a, "/"); name=a[n]
        mem_mb=mem_kb/1024
        printf "  %-8s %-25s %.2f MB\n", pid, name, mem_mb
    }' | while read -r line; do
        echo -e "${WHITE}${line}${NC}"
        echo "  $line" >> "$LOG_FILE"
    done
}
 
# Inicio

write_log "=== INICIO DO MONITORAMENTO DE SWAP ===" "INFO"
 
# Coleta dados
get_swap_info
 
# Exibe painel
show_swap_status
 
# Grava dados no log
write_log "Swap: Total=${SWAP_TOTAL_MB}MB | Usado=${SWAP_USADO_MB}MB | Livre=${SWAP_LIVRE_MB}MB | Uso=${SWAP_PERCENT}%" "INFO"
 
# Verifica se ultrapassou o limite
if [ "$SWAP_PERCENT_INT" -gt "$LIMITE_SWAP" ] 2>/dev/null; then
    echo ""
    echo -e "${RED}  ALERTA: Uso de swap em ${SWAP_PERCENT}% - acima do limite de ${LIMITE_SWAP}%!${NC}"
    echo -e "${YELLOW}  Verifique os processos consumindo mais memoria.${NC}"
 
    write_log "ALERTA: Uso de swap em ${SWAP_PERCENT}% - acima do limite de ${LIMITE_SWAP}%!" "AVISO"
 
    show_top_processos
else
    echo ""
    echo -e "${GREEN}  OK: Uso de swap em ${SWAP_PERCENT}% - dentro do limite de ${LIMITE_SWAP}%.${NC}"
    echo ""
    write_log "OK: Uso de swap em ${SWAP_PERCENT}% - dentro do limite." "SUCESSO"
fi
 
write_log "=== FIM DO MONITORAMENTO DE SWAP ===" "INFO"
 
echo ""
echo -e "${GREEN}  Log salvo em: $LOG_FILE${NC}"
echo ""
 
exit 0