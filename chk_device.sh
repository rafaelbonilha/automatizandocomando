#
# Script em Bash que valida o dispositivo HDD/SSD/NVMe
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x#
#
# 2-) Como usar.:
#
# a-) Instale a dependencia smartmontools.:
# Ubuntu/Debian.: sudo apt install smartmontools
# CentOS/RHEL.: sudo yum install smartmontools"
#
# b-) Uso Basico.:
# ./chk_device.sh
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab
#
#!/bin/bash

# Verifica se esta rodando como root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERRO: Este script precisa ser executado como root!"
    echo "Execute: sudo ./smart_check.sh"
    exit 1
fi
 
# Verifica se smartctl esta instalado
if ! command -v smartctl &>/dev/null; then
    echo "ERRO: 'smartctl' nao encontrado."
    echo "Instale com:"
    echo "  Ubuntu/Debian : sudo apt install smartmontools"
    echo "  CentOS/RHEL   : sudo yum install smartmontools"
    exit 1
fi
 
# Configs
LOG_DIR="$HOME/SmartCheck"
LOG_FILE="$LOG_DIR/SmartCheck_$(date '+%Y-%m-%d_%H-%M-%S').log"
 
mkdir -p "$LOG_DIR"
 
# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'
 
# Funcoes
 
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
 
write_section() {
    local title="$1"
    local line
    line=$(printf '=%.0s' {1..60})
    echo ""
    echo -e "${CYAN}${line}${NC}"
    echo -e "${CYAN}  ${title}${NC}"
    echo -e "${CYAN}${line}${NC}"
}
 
add_to_report() {
    echo "$1" >> "$LOG_FILE"
}
 
print_field() {
    printf "  %-28s : %s\n" "$1" "$2"
}
 
get_discos() {
    smartctl --scan 2>/dev/null | awk '{print $1}'
}
 
get_smart_atributo() {
    local output="$1"
    local nome="$2"
    local linha valor
 
    linha=$(echo "$output" | grep -iE "$nome" | head -1)
    if [ -n "$linha" ]; then
        
        valor=$(echo "$linha" | awk '{print $NF}')
        echo "$valor"
    else
        echo "N/A"
    fi
}

check_disco() {
    local disco="$1"
 
    write_section "DISCO: $disco"
    write_log "Verificando disco $disco" "INFO"
 
    # Saidas do smartctl
    local info saude atributos
    info=$(smartctl -i "$disco" 2>/dev/null)
    saude=$(smartctl -H "$disco" 2>/dev/null)
    atributos=$(smartctl -A "$disco" 2>/dev/null)
 
    # Extrai informacoes basicas
    local modelo serie firmware capacidade tipo
 
    modelo=$(echo "$info" | grep -iE "^(Device Model|Model Number|Product)" \
        | head -1 | sed 's/.*:[[:space:]]*//' | xargs)
 
    serie=$(echo "$info" | grep -iE "^Serial Number" \
        | head -1 | sed 's/.*:[[:space:]]*//' | xargs)
 
    firmware=$(echo "$info" | grep -iE "^Firmware Version" \
        | head -1 | sed 's/.*:[[:space:]]*//' | xargs)
 
    capacidade=$(echo "$info" | grep -iE "^(User Capacity|Total NVM Capacity|Namespace 1 Size)" \
        | head -1 | sed 's/.*:[[:space:]]*//' | xargs)
 
    tipo=$(echo "$info" | grep -iE "^(Rotation Rate|Form Factor)" \
        | head -1 | sed 's/.*:[[:space:]]*//' | xargs)
 
    # Tipo alternativo para NVMe
    if [ -z "$tipo" ]; then
        echo "$info" | grep -qi "NVMe" && tipo="NVMe SSD" || tipo="N/A"
    fi
 
    local status_texto status_cor
    if echo "$saude" | grep -qi "PASSED\|OK"; then
        status_texto="PASSED"
        status_cor=$GREEN
    else
        status_texto="FAILED"
        status_cor=$RED
    fi
 
    # Atributos Importantes
  
    local temperatura horas_uso erros_realocados setores_pendentes
    local erros_leitura erros_uncorrectable ciclos_ligamento
 
    temperatura=$(get_smart_atributo "$atributos" "Temperature_Celsius|Airflow_Temperature|Temperature")
    horas_uso=$(get_smart_atributo "$atributos" "Power_On_Hours|Power_On_Hours_and_Msec")
    erros_realocados=$(get_smart_atributo "$atributos" "Reallocated_Sector_Ct|Reallocated_Event_Count")
    setores_pendentes=$(get_smart_atributo "$atributos" "Current_Pending_Sector")
    erros_leitura=$(get_smart_atributo "$atributos" "Raw_Read_Error_Rate")
    erros_uncorrectable=$(get_smart_atributo "$atributos" "Offline_Uncorrectable")
    ciclos_ligamento=$(get_smart_atributo "$atributos" "Power_Cycle_Count")
 
    # NVMe: busca campos diferentes se atributos SMART nao existirem
    if [ "$temperatura" = "N/A" ]; then
        temperatura=$(smartctl -a "$disco" 2>/dev/null \
            | grep -iE "^Temperature:" | awk '{print $2}')
        [ -z "$temperatura" ] && temperatura="N/A"
    fi
    if [ "$horas_uso" = "N/A" ]; then
        horas_uso=$(smartctl -a "$disco" 2>/dev/null \
            | grep -iE "Power On Hours" | awk '{print $NF}')
        [ -z "$horas_uso" ] && horas_uso="N/A"
    fi
 
    # Exibe no terminal
    echo ""
    echo -e "${WHITE}$(print_field "Modelo"          "${modelo:-N/A}")${NC}"
    echo -e "${WHITE}$(print_field "Numero de serie" "${serie:-N/A}")${NC}"
    echo -e "${WHITE}$(print_field "Firmware"        "${firmware:-N/A}")${NC}"
    echo -e "${WHITE}$(print_field "Capacidade"      "${capacidade:-N/A}")${NC}"
    echo -e "${WHITE}$(print_field "Tipo"            "${tipo:-N/A}")${NC}"
    echo ""
    echo -e "${status_cor}$(print_field "Status S.M.A.R.T." "$status_texto")${NC}"
 
    # Temperatura
    local temp_cor=$GREEN
    if [[ "$temperatura" =~ ^[0-9]+$ ]]; then
        if   [ "$temperatura" -gt 60 ]; then temp_cor=$RED
        elif [ "$temperatura" -gt 45 ]; then temp_cor=$YELLOW
        fi
    fi
    echo -e "${temp_cor}$(print_field "Temperatura" "${temperatura} C")${NC}"
    echo -e "${WHITE}$(print_field "Horas de uso"       "${horas_uso} h")${NC}"
    echo -e "${WHITE}$(print_field "Ciclos de ligamento" "$ciclos_ligamento")${NC}"
 
    # Atributos Importantes - Alertas
    local cor_realocados=$GREEN cor_pendentes=$GREEN cor_uncorrect=$GREEN
    [[ "$erros_realocados"    =~ ^[1-9] ]] && cor_realocados=$RED
    [[ "$setores_pendentes"   =~ ^[1-9] ]] && cor_pendentes=$RED
    [[ "$erros_uncorrectable" =~ ^[1-9] ]] && cor_uncorrect=$RED
 
    echo -e "${cor_realocados}$(print_field "Setores realocados"    "$erros_realocados")${NC}"
    echo -e "${cor_pendentes}$(print_field  "Setores pendentes"     "$setores_pendentes")${NC}"
    echo -e "${cor_uncorrect}$(print_field  "Erros nao corrigiveis" "$erros_uncorrectable")${NC}"
    echo -e "${WHITE}$(print_field           "Erros de leitura (raw)" "$erros_leitura")${NC}"
 
    # Resumo
    echo ""
    if [ "$status_texto" = "FAILED" ]; then
        echo -e "${RED}  *** ATENCAO: Este disco REPROVOU no teste S.M.A.R.T.! ***${NC}"
        write_log "FALHA S.M.A.R.T. no disco $disco ($modelo)" "ERRO"
    elif [[ "$erros_realocados" =~ ^[1-9] ]] || \
         [[ "$setores_pendentes" =~ ^[1-9] ]] || \
         [[ "$erros_uncorrectable" =~ ^[1-9] ]]; then
        echo -e "${YELLOW}  *** AVISO: Disco passou no S.M.A.R.T. mas tem atributos criticos! ***${NC}"
        write_log "AVISO: Disco $disco passou no S.M.A.R.T. mas tem atributos criticos" "AVISO"
    else
        echo -e "${GREEN}  Disco saudavel.${NC}"
        write_log "OK: Disco $disco saudavel (PASSED)" "SUCESSO"
    fi
 
    # Relatorio do log
    add_to_report ""
    add_to_report "=== DISCO: $disco ==="
    add_to_report "  Modelo          : ${modelo:-N/A}"
    add_to_report "  Serie           : ${serie:-N/A}"
    add_to_report "  Status SMART    : $status_texto"
    add_to_report "  Temperatura     : $temperatura C"
    add_to_report "  Horas de uso    : $horas_uso h"
    add_to_report "  Setores realoc. : $erros_realocados"
    add_to_report "  Setores pend.   : $setores_pendentes"
    add_to_report "  Erros uncorr.   : $erros_uncorrectable"
    add_to_report "  Erros leitura   : $erros_leitura"
    add_to_report ""
}
 
# Inicio
 
clear
 
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}   VALIDACAO S.M.A.R.T. - HDD / SSD     ${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
 
# Cabecalho no log
{
    echo "=================================================="
    echo "  VALIDACAO S.M.A.R.T. - $(date '+%d/%m/%Y %H:%M:%S')"
    echo "  Executado por: $(whoami) em $(hostname)"
    echo "=================================================="
    echo ""
} >> "$LOG_FILE"
 
write_log "=== INICIO DA VALIDACAO S.M.A.R.T. ===" "INFO"
 
# Lista discos
mapfile -t discos < <(get_discos)
 
if [ "${#discos[@]}" -eq 0 ]; then
    echo -e "${YELLOW}  Nenhum disco encontrado pelo smartctl.${NC}"
    write_log "Nenhum disco encontrado" "AVISO"
    exit 0
fi
 
echo -e "${CYAN}  Discos encontrados: ${#discos[@]}${NC}"
write_log "Discos encontrados: ${#discos[@]}" "INFO"
 
for disco in "${discos[@]}"; do
    check_disco "$disco"
done
 
{
    echo "=================================================="
    echo "  Concluido em: $(date '+%d/%m/%Y %H:%M:%S')"
    echo "=================================================="
} >> "$LOG_FILE"
 
write_log "=== FIM DA VALIDACAO S.M.A.R.T. ===" "INFO"
 
echo ""
echo -e "${GREEN}  Log salvo em: $LOG_FILE${NC}"
echo ""
 
exit 0