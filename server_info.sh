#
# Script em Bash que gera informações sobre o servidor e salva a atividade em um arquivo txt
#
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x server_info.sh
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
# ./server_info.sh
#
#   Sistema operacional e hardware
#   CPU, memoria e disco
#   Rede e conectividade
#   Servicos e processos em execucao
#   Eventos recentes do sistema (journalctl)
#   Usuarios conectados
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab
#
#!/bin/bash

LOG_DIR="$HOME/InfoServidor"
LOG_FILE="$LOG_DIR/InfoServidor_$(date '+%Y-%m-%d').log"
REPORT_FILE="$LOG_DIR/Relatorio_$(date '+%Y-%m-%d_%H-%M-%S').txt"
 
mkdir -p "$LOG_DIR"
 
# -----------------------------------------------------------
# CORES
# -----------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # sem cor
 
# -----------------------------------------------------------
# FUNCOES UTILITARIAS
# -----------------------------------------------------------
 
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
    echo "$1" >> "$REPORT_FILE"
}
 
press_any_key() {
    echo ""
    echo -e "${GRAY}Pressione ENTER para continuar...${NC}"
    read -r
}
 
print_field() {
    printf "  %-28s : %s\n" "$1" "$2"
}
 
# -----------------------------------------------------------
# FUNCOES DE COLETA
# -----------------------------------------------------------
 
get_sistema_operacional() {
    write_section "SISTEMA OPERACIONAL"
    write_log "Coletando informacoes do sistema operacional" "INFO"
 
    local hostname
    hostname=$(hostname)
    local os_name
    os_name=$(grep '^PRETTY_NAME' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
    local kernel
    kernel=$(uname -r)
    local arch
    arch=$(uname -m)
    local manufacturer
    manufacturer=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo "N/A")
    local model
    model=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "N/A")
    local serial
    serial=$(sudo cat /sys/class/dmi/id/product_serial 2>/dev/null || echo "N/A (requer sudo)")
    local last_boot
    last_boot=$(who -b 2>/dev/null | awk '{print $3, $4}')
    local uptime_str
    uptime_str=$(uptime -p 2>/dev/null || uptime)
    local timezone
    timezone=$(timedatectl 2>/dev/null | grep "Time zone" | awk '{print $3}' || date +%Z)
 
    echo -e "${WHITE}"
    print_field "Nome do computador"   "$hostname"
    print_field "Sistema operacional"  "$os_name"
    print_field "Kernel"               "$kernel"
    print_field "Arquitetura"          "$arch"
    print_field "Fabricante"           "$manufacturer"
    print_field "Modelo"               "$model"
    print_field "Numero de serie"      "$serial"
    print_field "Ultimo boot"          "$last_boot"
    print_field "Uptime"               "$uptime_str"
    print_field "Fuso horario"         "$timezone"
    echo -e "${NC}"
 
    add_to_report ""
    add_to_report "=== SISTEMA OPERACIONAL ==="
    add_to_report "$(print_field "Nome do computador"  "$hostname")"
    add_to_report "$(print_field "Sistema operacional" "$os_name")"
    add_to_report "$(print_field "Kernel"              "$kernel")"
    add_to_report "$(print_field "Arquitetura"         "$arch")"
    add_to_report "$(print_field "Fabricante"          "$manufacturer")"
    add_to_report "$(print_field "Modelo"              "$model")"
    add_to_report "$(print_field "Ultimo boot"         "$last_boot")"
    add_to_report "$(print_field "Uptime"              "$uptime_str")"
    add_to_report "$(print_field "Fuso horario"        "$timezone")"
}
 
get_info_cpu() {
    write_section "PROCESSADOR (CPU)"
    write_log "Coletando informacoes de CPU" "INFO"
 
    local cpu_name
    cpu_name=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    local cores_fisicos
    cores_fisicos=$(grep -c '^processor' /proc/cpuinfo)
    local velocidade
    velocidade=$(grep 'cpu MHz' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs | cut -d. -f1)
    local arch
    arch=$(uname -m)
    local uso_cpu
    uso_cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1 2>/dev/null || echo "N/A")
 
    echo -e "${WHITE}"
    print_field "Nome"                  "$cpu_name"
    print_field "Nucleos logicos"       "$cores_fisicos"
    print_field "Velocidade base (MHz)" "$velocidade"
    print_field "Arquitetura"           "$arch"
 
    if [ "$uso_cpu" != "N/A" ] && [ "$uso_cpu" -gt 80 ] 2>/dev/null; then
        echo -e "${RED}$(print_field "Uso atual (%)" "$uso_cpu")${NC}"
    else
        print_field "Uso atual (%)" "$uso_cpu"
    fi
    echo -e "${NC}"
 
    add_to_report ""
    add_to_report "=== PROCESSADOR ==="
    add_to_report "$(print_field "Nome"            "$cpu_name")"
    add_to_report "$(print_field "Nucleos logicos" "$cores_fisicos")"
    add_to_report "$(print_field "Velocidade MHz"  "$velocidade")"
    add_to_report "$(print_field "Uso atual (%)"   "$uso_cpu")"
}
 
get_info_memoria() {
    write_section "MEMORIA RAM"
    write_log "Coletando informacoes de memoria" "INFO"
 
    local total_kb usado_kb livre_kb
    total_kb=$(grep MemTotal  /proc/meminfo | awk '{print $2}')
    livre_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    usado_kb=$(( total_kb - livre_kb ))
 
    local total_gb usado_gb livre_gb percent_uso
    total_gb=$(awk "BEGIN {printf \"%.2f\", $total_kb/1048576}")
    usado_gb=$(awk "BEGIN {printf \"%.2f\", $usado_kb/1048576}")
    livre_gb=$(awk "BEGIN {printf \"%.2f\", $livre_kb/1048576}")
    percent_uso=$(awk "BEGIN {printf \"%.1f\", ($usado_kb/$total_kb)*100}")
    local percent_int
    percent_int=$(echo "$percent_uso" | cut -d. -f1)
 
    echo -e "${WHITE}"
    print_field "Total (GB)"    "$total_gb"
    print_field "Usado (GB)"    "$usado_gb"
    print_field "Livre (GB)"    "$livre_gb"
 
    if [ "$percent_int" -gt 85 ] 2>/dev/null; then
        echo -e "${RED}$(print_field "Uso atual (%)" "$percent_uso")${NC}"
    elif [ "$percent_int" -gt 70 ] 2>/dev/null; then
        echo -e "${YELLOW}$(print_field "Uso atual (%)" "$percent_uso")${NC}"
    else
        echo -e "${WHITE}$(print_field "Uso atual (%)" "$percent_uso")${NC}"
    fi
 
    echo ""
    echo -e "${YELLOW}  Informacoes de swap:${NC}"
    free -h | grep -i swap | awk '{printf "    Total: %s  Usado: %s  Livre: %s\n", $2, $3, $4}'
 
    add_to_report ""
    add_to_report "=== MEMORIA RAM ==="
    add_to_report "$(print_field "Total (GB)"   "$total_gb")"
    add_to_report "$(print_field "Usado (GB)"   "$usado_gb")"
    add_to_report "$(print_field "Livre (GB)"   "$livre_gb")"
    add_to_report "$(print_field "Uso atual (%)" "$percent_uso")"
}
 
get_info_disco() {
    write_section "DISCOS E ARMAZENAMENTO"
    write_log "Coletando informacoes de disco" "INFO"
 
    add_to_report ""
    add_to_report "=== DISCOS ==="
 
    echo ""
    df -h --output=source,size,used,avail,pcent,target 2>/dev/null | grep '^/dev' | while read -r source size used avail pcent target; do
        local percent_num
        percent_num=$(echo "$pcent" | tr -d '%')
 
        if [ "$percent_num" -gt 90 ] 2>/dev/null; then
            color=$RED
        elif [ "$percent_num" -gt 75 ] 2>/dev/null; then
            color=$YELLOW
        else
            color=$WHITE
        fi
 
        echo -e "${CYAN}  Disco: $source  Montado em: $target${NC}"
        echo -e "${WHITE}    Total   : $size${NC}"
        echo -e "${color}    Usado   : $used ($pcent)${NC}"
        echo -e "${WHITE}    Livre   : $avail${NC}"
        echo ""
 
        add_to_report "  Disco: $source  Total=$size  Usado=$used ($pcent)  Livre=$avail  Mount=$target"
    done
}
 
get_info_rede() {
    write_section "REDE E CONECTIVIDADE"
    write_log "Coletando informacoes de rede" "INFO"
 
    add_to_report ""
    add_to_report "=== REDE ==="
 
    echo ""
    # Lista interfaces ativas
    if command -v ip &>/dev/null; then
        ip -o addr show | grep 'inet ' | while read -r num iface rest; do
            local ip_cidr
            ip_cidr=$(echo "$rest" | awk '{print $1}')
            local mac
            mac=$(ip link show "$iface" 2>/dev/null | awk '/ether/{print $2}')
            echo -e "${CYAN}  Interface: $iface${NC}"
            echo -e "${WHITE}    IP/Mascara    : $ip_cidr${NC}"
            echo -e "${WHITE}    MAC           : ${mac:-N/A}${NC}"
            add_to_report "  Interface: $iface  IP: $ip_cidr  MAC: ${mac:-N/A}"
        done
    fi
 
    # Gateway
    local gateway
    gateway=$(ip route | grep default | awk '{print $3}' | head -1)
    echo -e "${WHITE}  Gateway padrao    : ${gateway:-N/A}${NC}"
 
    # DNS
    local dns
    dns=$(grep '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
    echo -e "${WHITE}  DNS               : ${dns:-N/A}${NC}"
 
    # Teste de conectividade
    echo ""
    echo -e "${YELLOW}  Teste de conectividade:${NC}"
    for host in "8.8.8.8" "1.1.1.1" "google.com"; do
        if ping -c 1 -W 2 "$host" &>/dev/null; then
            echo -e "${GREEN}    $(printf '%-15s' "$host") : OK${NC}"
        else
            echo -e "${RED}    $(printf '%-15s' "$host") : FALHOU${NC}"
        fi
    done
}
 
get_info_servicos() {
    write_section "SERVICOS DO SISTEMA"
    write_log "Coletando informacoes de servicos" "INFO"
 
    if ! command -v systemctl &>/dev/null; then
        echo -e "${YELLOW}  systemctl nao disponivel neste sistema.${NC}"
        return
    fi
 
    local total rodando parados
    total=$(systemctl list-units --type=service --no-pager --no-legend 2>/dev/null | wc -l)
    rodando=$(systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | wc -l)
    parados=$(systemctl list-units --type=service --state=dead --no-pager --no-legend 2>/dev/null | wc -l)
 
    echo -e "${WHITE}  Total de servicos : $total${NC}"
    echo -e "${GREEN}  Em execucao       : $rodando${NC}"
    echo -e "${YELLOW}  Parados           : $parados${NC}"
 
    echo ""
    echo -e "${YELLOW}  Servicos com falha (podem indicar problema):${NC}"
    local falhos
    falhos=$(systemctl list-units --type=service --state=failed --no-pager --no-legend 2>/dev/null)
    if [ -z "$falhos" ]; then
        echo -e "${GREEN}    Nenhum servico com falha encontrado.${NC}"
    else
        echo -e "${RED}$falhos${NC}"
        write_log "Servicos com falha encontrados" "AVISO"
    fi
 
    add_to_report ""
    add_to_report "=== SERVICOS ==="
    add_to_report "  Total: $total  Rodando: $rodando  Parados: $parados"
}
 
get_top_processos() {
    write_section "TOP 15 PROCESSOS POR CONSUMO"
    write_log "Coletando top processos" "INFO"
 
    echo ""
    echo -e "${WHITE}$(printf '  %-8s %-25s %-10s %-10s %-8s\n' 'PID' 'NOME' 'CPU(%)' 'RAM(MB)' 'THREADS')${NC}"
    echo "  $(printf '%.0s-' {1..65})"
 
    ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1 && NR<=16 {
        pid=$2; cpu=$3; mem_kb=$6; cmd=$11
        # pega so o nome do binario
        n=split(cmd, a, "/"); name=a[n]
        # converte KB para MB
        mem_mb=mem_kb/1024
        printf "  %-8s %-25s %-10s %-10.1f\n", pid, name, cpu, mem_mb
    }'
 
    add_to_report ""
    add_to_report "=== TOP 15 PROCESSOS ==="
    ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1 && NR<=16 {
        printf "  PID=%-6s Nome=%-25s CPU=%-8s RAM=%.1fMB\n", $2, $11, $3, $6/1024
    }' >> "$REPORT_FILE"
}
 
get_eventos_recentes() {
    write_section "EVENTOS RECENTES DO SISTEMA (ultimas 24h)"
    write_log "Coletando eventos recentes" "INFO"
 
    if ! command -v journalctl &>/dev/null; then
        echo -e "${YELLOW}  journalctl nao disponivel. Verificando /var/log/syslog...${NC}"
        if [ -f /var/log/syslog ]; then
            grep "$(date '+%b %e')" /var/log/syslog | grep -i 'error\|fail' | tail -10
        fi
        return
    fi
 
    local erros avisos
    erros=$(journalctl -p err --since "24 hours ago" --no-pager -q 2>/dev/null | wc -l)
    avisos=$(journalctl -p warning --since "24 hours ago" --no-pager -q 2>/dev/null | wc -l)
 
    echo -e "${RED}  Erros encontrados  : $erros${NC}"
    echo -e "${YELLOW}  Avisos encontrados : $avisos${NC}"
 
    if [ "$erros" -gt 0 ] 2>/dev/null; then
        echo ""
        echo -e "${RED}  Ultimos erros:${NC}"
        journalctl -p err --since "24 hours ago" --no-pager -q 2>/dev/null | tail -10 | while read -r line; do
            echo -e "${RED}    $line${NC}"
        done
    fi
 
    add_to_report ""
    add_to_report "=== EVENTOS (24h) ==="
    add_to_report "  Erros: $erros  Avisos: $avisos"
}
 
get_usuarios_conectados() {
    write_section "USUARIOS CONECTADOS"
    write_log "Coletando usuarios conectados" "INFO"
 
    echo ""
    who 2>/dev/null || echo "  Nao foi possivel listar usuarios."
 
    add_to_report ""
    add_to_report "=== USUARIOS CONECTADOS ==="
    who 2>/dev/null >> "$REPORT_FILE"
}
 
get_relatorio_completo() {
    echo ""
    echo -e "${CYAN}Gerando relatorio completo...${NC}"
 
    {
        echo "RELATORIO DE INFORMACOES DO SERVIDOR"
        echo "Gerado em: $(date '+%d/%m/%Y %H:%M:%S')"
        echo "Servidor : $(hostname)"
        printf '=%.0s' {1..60}
        echo ""
    } > "$REPORT_FILE"
 
    get_sistema_operacional
    get_info_cpu
    get_info_memoria
    get_info_disco
    get_info_rede
    get_info_servicos
    get_top_processos
    get_eventos_recentes
    get_usuarios_conectados
 
    echo ""
    echo -e "${GREEN}Relatorio salvo em: $REPORT_FILE${NC}"
    write_log "Relatorio completo gerado em $REPORT_FILE" "SUCESSO"
}
 
# -----------------------------------------------------------
# INICIO
# -----------------------------------------------------------
 
clear
 
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}     INFORMACOES DO SERVIDOR LINUX       ${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
 
write_log "=== INICIO DA COLETA DE INFORMACOES ==="
 
while true; do
    echo ""
    echo -e "${YELLOW}OPCOES DISPONIVEIS:${NC}"
    echo -e "${WHITE}1.  Sistema operacional e hardware${NC}"
    echo -e "${WHITE}2.  Processador (CPU)${NC}"
    echo -e "${WHITE}3.  Memoria RAM${NC}"
    echo -e "${WHITE}4.  Discos e armazenamento${NC}"
    echo -e "${WHITE}5.  Rede e conectividade${NC}"
    echo -e "${WHITE}6.  Servicos do sistema${NC}"
    echo -e "${WHITE}7.  Top 15 processos por consumo${NC}"
    echo -e "${WHITE}8.  Eventos recentes (24h)${NC}"
    echo -e "${WHITE}9.  Usuarios conectados${NC}"
    echo -e "${WHITE}10. Relatorio completo (salva txt)${NC}"
    echo -e "${WHITE}0.  Sair${NC}"
 
    echo ""
    read -rp "Escolha uma opcao: " opcao
 
    case "$opcao" in
        1)  get_sistema_operacional ;;
        2)  get_info_cpu ;;
        3)  get_info_memoria ;;
        4)  get_info_disco ;;
        5)  get_info_rede ;;
        6)  get_info_servicos ;;
        7)  get_top_processos ;;
        8)  get_eventos_recentes ;;
        9)  get_usuarios_conectados ;;
        10) get_relatorio_completo ;;
        0)  break ;;
        *)  echo -e "${YELLOW}  Opcao invalida.${NC}" ;;
    esac
 
    if [ "$opcao" != "0" ]; then
        press_any_key
        clear
        echo -e "${CYAN}=========================================${NC}"
        echo -e "${CYAN}     INFORMACOES DO SERVIDOR LINUX       ${NC}"
        echo -e "${CYAN}=========================================${NC}"
    fi
done
 
write_log "=== FIM DA COLETA DE INFORMACOES ==="
 
echo ""
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}          FERRAMENTA ENCERRADA           ${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
echo -e "${GREEN}Log salvo em: $LOG_FILE${NC}"
echo ""
 
if [ -f "$LOG_FILE" ]; then
    echo -e "${YELLOW}Ultimas operacoes realizadas:${NC}"
    echo ""
    tail -10 "$LOG_FILE" | while read -r linha; do
        if echo "$linha" | grep -q "SUCESSO"; then
            echo -e "${GREEN}$linha${NC}"
        elif echo "$linha" | grep -q "ERRO"; then
            echo -e "${RED}$linha${NC}"
        elif echo "$linha" | grep -q "AVISO"; then
            echo -e "${YELLOW}$linha${NC}"
        else
            echo -e "${GRAY}$linha${NC}"
        fi
    done
fi
 
echo ""
echo -e "${GRAY}Pressione ENTER para sair...${NC}"
read -r