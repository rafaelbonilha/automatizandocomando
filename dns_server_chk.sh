#
# Script em Bash que valida a velocidade do servidor dns e salva a atividade em um arquivo txt
#
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x dns_server_chk.sh
#
# 2-) Instale as dependencias.:
#  Debian.:
#  sudo apt install  notify-send dnsutils
#
#  RHEL/CentOS/Fedora.:
#  sudo dnf install notify-send bind-utils ou
#  sudo yum install notify-send bind-utils (CentOS)
# 
# Instale o iptables-persistent para não perder as regras do iptables em caso de reinicializacao
# sudo apt install iptables-persistent
# Para sistemas CentOS/RHEL.:
# sudo yum install iptables-persistent
#
# 3-) Como usar.:
#
# Uso Basico.:
# ./dns_server_chk.sh
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab
#
#!/bin/bash

# Configs
LOG_DIR="$HOME/DNSCheck"
LOG_FILE="$LOG_DIR/DNSCheck_$(date '+%Y-%m-%d_%H-%M-%S').txt"

mkdir -p "$LOG_DIR"

# Cores

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

measure_dns() {
    local server="$1"
    local start end elapsed

    start=$(date +%s%3N)
    dig @"$server" whitehouse.gov +time=5 +tries=1 > /dev/null 2>&1
    end=$(date +%s%3N)

    elapsed=$(( end - start ))
    echo "$elapsed"
}

check_dns() {
    local name="$1"
    local pri_ipv4="$2"
    local sec_ipv4="$3"

    local pri_elapsed sec_elapsed
    pri_elapsed=$(measure_dns "$pri_ipv4")
    sec_elapsed=$(measure_dns "$sec_ipv4")

    # Exibe no terminal
    printf '   "%-50s" "%s" "%s ms" "%s" "%s ms"\n' \
        "$name" "$pri_ipv4" "$pri_elapsed" "$sec_ipv4" "$sec_elapsed"

    # Grava no log
    write_log "$name | Pri: $pri_ipv4 (${pri_elapsed} ms) | Sec: $sec_ipv4 (${sec_elapsed} ms)" "INFO"
}

# Valida dependencia

if ! command -v dig &>/dev/null; then
    echo -e "${RED}ERRO: 'dig' nao encontrado.${NC}"
    echo "Instale com:"
    echo "  Ubuntu/Debian : sudo apt install dnsutils"
    echo "  CentOS/RHEL   : sudo yum install bind-utils"
    exit 1
fi

# Inicio

COLUMNS_HEADER='  "Company"; "IPv4 primary"; "Latency in ms"; "IPv4 secondary"; "Latency in ms"'

echo "Checking speed of public DNS servers..."
echo "$COLUMNS_HEADER"

# Cabecalho
{
    echo "=================================================="
    echo "  VELOCIDADE DO SERVIDOR DNS - $(date '+%d/%m/%Y %H:%M:%S')"
    echo "  Executado por: $(whoami) em $(hostname)"
    echo "=================================================="
    echo "$COLUMNS_HEADER"
    echo ""
} >> "$LOG_FILE"

# Verificacoes DNS
check_dns "Cloudflare"                                                   1.1.1.1         1.0.0.1
check_dns "Cloudflare with malware blocklist"                            1.1.1.2         1.0.0.2
check_dns "Cloudflare with malware+adult blocklist"                      1.1.1.3         1.0.0.3
check_dns "DNS.Watch"                                                    84.200.69.80    84.200.70.40
check_dns "FreeDNS Vienna"                                               37.235.1.174    37.235.1.177
check_dns "Google Public DNS"                                            8.8.8.8         8.8.4.4
check_dns "Level3 one"                                                   4.2.2.1         4.2.2.1
check_dns "Level3 two"                                                   4.2.2.2         4.2.2.2
check_dns "Level3 three"                                                 4.2.2.3         4.2.2.3
check_dns "Level3 four"                                                  4.2.2.4         4.2.2.4
check_dns "Level3 five"                                                  4.2.2.5         4.2.2.5
check_dns "Level3 six"                                                   4.2.2.6         4.2.2.6
check_dns "OpenDNS Basic"                                                208.67.222.222  208.67.220.220
check_dns "OpenDNS Family Shield"                                        208.67.222.123  208.67.220.123
check_dns "OpenNIC"                                                      94.247.43.254   94.247.43.254
check_dns "Quad9 with malware blocklist, with DNSSEC"                    9.9.9.9         9.9.9.9
check_dns "Quad9, no malware blocklist, no DNSSEC"                       9.9.9.10        9.9.9.10
check_dns "Quad9, with malware blocklist, with DNSSEC, with EDNS"        9.9.9.11        9.9.9.11
check_dns "Quad9, with malware blocklist, with DNSSEC, NXDOMAIN only"    9.9.9.12        9.9.9.12
check_dns "Verisign Public DNS"                                          64.6.64.6       64.6.65.6

# Rodape

{
    echo ""
    echo "=================================================="
    echo "  Concluido em: $(date '+%d/%m/%Y %H:%M:%S')"
    echo "=================================================="
} >> "$LOG_FILE"

echo ""
echo -e "${GREEN}✅ Log salvo em: $LOG_FILE${NC}"
exit 0
