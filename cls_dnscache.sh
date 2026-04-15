#
# Script em Bash que efetua limpeza de cache dns
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x cls_dnscache.sh
#
#
# 2-) Como usar.:
# ./cls_dnscache.sh
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab
#
#
#!/bin/bash
# ==========================================================
#   LIMPEZA DE CACHE DNS
# ==========================================================

# Configs
LOG_DIR="$HOME/DNSFlush"
LOG_FILE="$LOG_DIR/DNSFlush_$(date '+%Y-%m-%d').log"
LIMITE_ENTRADAS=0

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Cria diretorio de log se não existir
mkdir -p "$LOG_DIR"

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
    line=$(printf '=%.0s' {1..55})
    echo ""
    echo -e "${CYAN}${line}${NC}"
    echo -e "${CYAN}  ${title}${NC}"
    echo -e "${CYAN}${line}${NC}"
}

add_to_report() {
    echo "$1" >> "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}ERRO: Este script precisa ser executado como root (sudo)!${NC}"
        echo -e "${YELLOW}Execute: sudo bash $0${NC}"
        exit 1
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_ID="$ID"
    elif command -v uname &>/dev/null; then
        OS_ID=$(uname -s | tr '[:upper:]' '[:lower:]')
    else
        OS_ID="unknown"
    fi
}

get_cache_atual() {
    write_section "CACHE DNS ATUAL"
    write_log "Consultando cache DNS atual" "INFO"

    local count=0

    # Linux com systemd-resolved
    if command -v resolvectl &>/dev/null; then
        local cache_output
        cache_output=$(resolvectl statistics 2>/dev/null)
        if [[ -n "$cache_output" ]]; then
            echo ""
            echo -e "${WHITE}${cache_output}${NC}"
            count=$(echo "$cache_output" | grep -i "current cache size" | awk '{print $NF}' 2>/dev/null || echo "0")
            write_log "Cache DNS com ~${count} entradas antes da limpeza" "INFO"
            add_to_report ""
            add_to_report "=== CACHE DNS ANTES DA LIMPEZA ==="
            add_to_report "$cache_output"
        else
            echo -e "${YELLOW}  Cache DNS vazio ou não disponível.${NC}"
            write_log "Cache DNS vazio antes da limpeza" "AVISO"
        fi

    # macOS
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${YELLOW}  Exibição detalhada do cache não disponível no macOS.${NC}"
        write_log "macOS: exibição do cache não suportada nativamente" "AVISO"
        add_to_report ""
        add_to_report "=== CACHE DNS ANTES DA LIMPEZA ==="
        add_to_report "  Exibição não disponível no macOS."
        count="-"

    else
        echo -e "${YELLOW}  Exibição do cache não suportada neste sistema.${NC}"
        write_log "Sistema sem suporte a exibição de cache DNS" "AVISO"
        count=0
    fi

    echo ""
    echo -e "${CYAN}  Total de entradas no cache: ${count}${NC}"
    echo "$count"
}

clear_cache_dns() {
    write_section "LIMPANDO CACHE DNS"
    write_log "Iniciando limpeza do cache DNS" "INFO"

    local sucesso=false

    # systemd-resolved (Ubuntu, Debian, Fedora, etc.)
    if command -v resolvectl &>/dev/null; then
        if resolvectl flush-caches &>/dev/null; then
            echo -e "${GREEN}  Cache DNS limpo com sucesso via resolvectl!${NC}"
            write_log "Cache DNS limpo com sucesso via resolvectl flush-caches" "SUCESSO"
            sucesso=true
        fi
    fi

    # nscd (Name Service Cache Daemon)
    if [[ "$sucesso" == false ]] && command -v nscd &>/dev/null; then
        if nscd -i hosts &>/dev/null || service nscd restart &>/dev/null; then
            echo -e "${GREEN}  Cache DNS limpo com sucesso via nscd!${NC}"
            write_log "Cache DNS limpo com sucesso via nscd" "SUCESSO"
            sucesso=true
        fi
    fi

    # systemd-resolved via systemctl
    if [[ "$sucesso" == false ]] && systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        if systemctl restart systemd-resolved &>/dev/null; then
            echo -e "${GREEN}  Cache DNS limpo via restart do systemd-resolved!${NC}"
            write_log "Cache DNS limpo via restart systemd-resolved" "SUCESSO"
            sucesso=true
        fi
    fi

    # macOS
    if [[ "$sucesso" == false ]] && [[ "$OSTYPE" == "darwin"* ]]; then
        if dscacheutil -flushcache &>/dev/null && killall -HUP mDNSResponder &>/dev/null; then
            echo -e "${GREEN}  Cache DNS limpo com sucesso no macOS!${NC}"
            write_log "Cache DNS limpo com sucesso via dscacheutil + mDNSResponder" "SUCESSO"
            sucesso=true
        fi
    fi

    if [[ "$sucesso" == false ]]; then
        echo -e "${RED}  ERRO: Não foi possível limpar o cache DNS neste sistema.${NC}"
        write_log "Erro: nenhum método de limpeza disponível encontrado" "ERRO"
        exit 1
    fi
}

confirm_limpeza_cache() {
    write_section "VERIFICANDO CACHE APÓS LIMPEZA"
    write_log "Verificando cache DNS após limpeza" "INFO"

    sleep 1

    local quantidade=0

    if command -v resolvectl &>/dev/null; then
        quantidade=$(resolvectl statistics 2>/dev/null \
            | grep -i "current cache size" \
            | awk '{print $NF}' 2>/dev/null || echo "0")
    fi

    if [[ "$quantidade" -eq "$LIMITE_ENTRADAS" ]] 2>/dev/null; then
        echo -e "${GREEN}  Cache DNS confirmado como vazio.${NC}"
        write_log "Limpeza confirmada: cache com ${quantidade} entradas" "SUCESSO"
    else
        echo -e "${YELLOW}  Cache ainda possui ${quantidade} entrada(s) — pode ser preenchimento automático do sistema.${NC}"
        write_log "Cache com ${quantidade} entradas após limpeza (preenchimento automático do SO)" "AVISO"
    fi

    add_to_report ""
    add_to_report "=== CACHE DNS APÓS LIMPEZA ==="
    add_to_report "  Entradas restantes: ${quantidade}"
}

# Reinicia se necessario, opcional

restart_servico_dns() {
    write_section "REINICIAR SERVIÇO DNS"

    read -rp "  Deseja reiniciar o serviço DNS? Isso pode causar lentidão momentânea. (S/N): " confirmar
    if [[ "$confirmar" != "S" && "$confirmar" != "s" ]]; then
        write_log "Reinício do serviço DNS cancelado pelo usuário" "AVISO"
        return
    fi

    write_log "Reiniciando serviço DNS" "INFO"

    local sucesso=false

    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        if systemctl restart systemd-resolved; then
            echo -e "${GREEN}  Serviço systemd-resolved reiniciado com sucesso!${NC}"
            write_log "systemd-resolved reiniciado com sucesso" "SUCESSO"
            sucesso=true
        fi
    fi

    if [[ "$sucesso" == false ]] && command -v nscd &>/dev/null; then
        if service nscd restart &>/dev/null || systemctl restart nscd &>/dev/null; then
            echo -e "${GREEN}  Serviço nscd reiniciado com sucesso!${NC}"
            write_log "nscd reiniciado com sucesso" "SUCESSO"
            sucesso=true
        fi
    fi

    if [[ "$sucesso" == false ]]; then
        echo -e "${RED}  Erro ao reiniciar serviço DNS: nenhum serviço compatível encontrado.${NC}"
        write_log "Erro ao reiniciar serviço DNS" "ERRO"
    fi
}

# Inicio

trap 'write_log "Erro na linha ${LINENO}: ${BASH_COMMAND}" "ERRO"; exit 1' ERR

check_root
detect_os
clear

echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}       LIMPEZA DE CACHE DNS              ${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

add_to_report "=================================================="
add_to_report "  LIMPEZA DE CACHE DNS - $(date '+%d/%m/%Y %H:%M:%S')"
add_to_report "  Executado por: $(whoami) em $(hostname)"
add_to_report "=================================================="

write_log "=== INICIO DA LIMPEZA DE CACHE DNS ===" "INFO"

# Passo 1: Exibe cache atual
get_cache_atual > /dev/null

# Passo 2: Confirmação do usuário
echo ""
read -rp "  Deseja limpar o cache DNS agora? (S/N): " confirmar
if [[ "$confirmar" != "S" && "$confirmar" != "s" ]]; then
    write_log "Limpeza cancelada pelo usuário" "AVISO"
    echo -e "${YELLOW}  Operação cancelada.${NC}"
    exit 0
fi

# Passo 3: Limpa o cache
clear_cache_dns

# Passo 4: Confirma limpeza
confirm_limpeza_cache

# Passo 5: Reinicia serviço (opcional)
restart_servico_dns

# Rodapé
add_to_report ""
add_to_report "=================================================="
add_to_report "  Concluído em: $(date '+%d/%m/%Y %H:%M:%S')"
add_to_report "=================================================="

write_log "=== FIM DA LIMPEZA DE CACHE DNS ===" "INFO"

echo ""
echo -e "${GREEN}  Log salvo em: ${LOG_FILE}${NC}"
echo ""

exit 0