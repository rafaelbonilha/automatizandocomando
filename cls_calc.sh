#
# Script em Bash que encerra a calculadora e salva a atividade em um artigo .txt
#
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x cls_calc.sh
#
#
# 2-) Como usar.:
#
# Uso Basico.:
# ./cls_calc.sh
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab
#
#!/bin/bash

# Configs
LOG_DIR="$HOME/KillCalc"
LOG_FILE="$LOG_DIR/KillCalc_$(date '+%Y-%m-%d').log"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
WHITE='\033[1;37m'
NC='\033[0m'

# Cria diretorio de log se nao existir
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

show_header() {
    local line
    line=$(printf '=%.0s' {1..55})
    echo ""
    echo -e "${CYAN}${line}${NC}"
    echo -e "${CYAN}  ENCERRAMENTO DA CALCULADORA${NC}"
    echo -e "${CYAN}${line}${NC}"
    echo ""
}

# Lista os nomes de processo conhecidos da calculadora
# por sistema operacional

get_calc_processes() {
    # Linux (GNOME, KDE, etc.)
    local procs=(
        "gnome-calculator"
        "kcalc"
        "xcalc"
        "galculator"
        "mate-calc"
        "qalculate-gtk"
        "speedcrunch"
        "calculator"
    )
    echo "${procs[@]}"
}

# Busca processos da calculadora em execucao

find_calc() {
    local found=()
    local procs
    read -ra procs <<< "$(get_calc_processes)"

    for proc in "${procs[@]}"; do
        local pids
        pids=$(pgrep -x "$proc" 2>/dev/null)
        if [[ -n "$pids" ]]; then
            while IFS= read -r pid; do
                found+=("$pid:$proc")
            done <<< "$pids"
        fi
    done

    echo "${found[@]}"
}

# Exibe status dos processos encontrados

show_calc_status() {
    local found=("$@")
    local line
    line=$(printf '=%.0s' {1..55})

    echo -e "${WHITE}  $(printf '%-10s' 'PID') $(printf '%-30s' 'Processo')${NC}"
    echo -e "${GRAY}  $(printf -- '-%.0s' {1..45})${NC}"

    for entry in "${found[@]}"; do
        local pid="${entry%%:*}"
        local name="${entry##*:}"
        echo -e "${WHITE}  $(printf '%-10s' "$pid") $(printf '%-30s' "$name")${NC}"
    done

    echo ""
    echo -e "${CYAN}  Total encontrado: ${#found[@]} processo(s)${NC}"
    echo -e "${CYAN}${line}${NC}"
    echo ""
}

# Encerra os processos da calculadora

kill_calc() {
    local found=("$@")
    local encerrados=0
    local falhas=0

    for entry in "${found[@]}"; do
        local pid="${entry%%:*}"
        local name="${entry##*:}"

        write_log "Encerrando processo: $name (PID: $pid)" "INFO"

        # Tenta encerrar graciosamente primeiro (SIGTERM)
        if kill -15 "$pid" 2>/dev/null; then
            sleep 1
            # Verifica se ainda esta rodando
            if kill -0 "$pid" 2>/dev/null; then
                # Força encerramento (SIGKILL)
                if kill -9 "$pid" 2>/dev/null; then
                    echo -e "${GREEN}  Processo $name (PID: $pid) encerrado forçadamente.${NC}"
                    write_log "Processo $name (PID: $pid) encerrado via SIGKILL" "SUCESSO"
                    ((encerrados++))
                else
                    echo -e "${RED}  Falha ao encerrar $name (PID: $pid).${NC}"
                    write_log "Falha ao encerrar $name (PID: $pid)" "ERRO"
                    ((falhas++))
                fi
            else
                echo -e "${GREEN}  Processo $name (PID: $pid) encerrado com sucesso.${NC}"
                write_log "Processo $name (PID: $pid) encerrado via SIGTERM" "SUCESSO"
                ((encerrados++))
            fi
        else
            echo -e "${RED}  Sem permissão ou falha ao encerrar $name (PID: $pid).${NC}"
            write_log "Falha ou sem permissão para encerrar $name (PID: $pid)" "ERRO"
            ((falhas++))
        fi
    done

    echo ""
    echo -e "${CYAN}  Resultado: ${encerrados} encerrado(s) | ${falhas} falha(s)${NC}"
    write_log "Resultado final: $encerrados encerrado(s), $falhas falha(s)" "INFO"
}

# Inicio

trap 'write_log "Erro inesperado na linha ${LINENO}: ${BASH_COMMAND}" "ERRO"; exit 1' ERR

show_header
write_log "=== INICIO DO ENCERRAMENTO DA CALCULADORA ===" "INFO"

# Passo 1: Busca processos
read -ra FOUND <<< "$(find_calc)"

if [[ ${#FOUND[@]} -eq 0 || -z "${FOUND[0]}" ]]; then
    echo -e "${YELLOW}  Nenhum processo de calculadora encontrado em execução.${NC}"
    echo ""
    write_log "Nenhum processo de calculadora encontrado" "AVISO"
else
    # Passo 2: Exibe processos encontrados
    echo -e "${WHITE}  Processos de calculadora encontrados:${NC}"
    show_calc_status "${FOUND[@]}"

    # Passo 3: Confirmacao do usuario
    read -rp "  Deseja encerrar todos os processos listados? (S/N): " confirmar
    if [[ "$confirmar" != "S" && "$confirmar" != "s" ]]; then
        write_log "Operação cancelada pelo usuário" "AVISO"
        echo -e "${YELLOW}  Operação cancelada.${NC}"
        echo ""
        exit 0
    fi

    echo ""

    # Passo 4: Encerra os processos
    kill_calc "${FOUND[@]}"
fi

write_log "=== FIM DO ENCERRAMENTO DA CALCULADORA ===" "INFO"
echo ""
echo -e "${GREEN}  Log salvo em: ${LOG_FILE}${NC}"
echo ""

exit 0