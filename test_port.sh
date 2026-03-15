#
# Script em Bash que testa a conectivadade numa porta determinada e salva a atividade em arquivo txt
#
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x test_port.sh
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
# ./test_port.sh
#
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab
#
#!/bin/bash

# Configuracoes
LOG_DIR="$HOME/HistoricoConexao"
LOG_FILE="$LOG_DIR/TestePorta_$(date +%Y-%m-%d).log"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Criar diretorio de log
mkdir -p "$LOG_DIR"

# Funcoes
write_log() {
    local message="$1"
    local status="${2:-INFO}"
    local timestamp=$(date "+%d/%m/%Y %H:%M:%S")
    local log_message="$timestamp | $status | $message"
    
    echo "$log_message" >> "$LOG_FILE"
    
    case $status in
        "ERRO")
            echo -e "${RED}$log_message${NC}"
            ;;
        "SUCESSO")
            echo -e "${GREEN}$log_message${NC}"
            ;;
        *)
            echo -e "${GRAY}$log_message${NC}"
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
                notify-send -i dialog-information "$title" "$message"
                ;;
            "Warning")
                notify-send -i dialog-warning "$title" "$message"
                ;;
            "Error")
                notify-send -i dialog-error "$title" "$message"
                ;;
        esac
    elif command -v zenity &> /dev/null; then
        case $type in
            "Info")
                zenity --info --title="$title" --text="$message" --timeout=5
                ;;
            "Warning")
                zenity --warning --title="$title" --text="$message" --timeout=5
                ;;
            "Error")
                zenity --error --title="$title" --text="$message" --timeout=5
                ;;
        esac
    else
        echo -e "\a" # aviso sonoro
    fi
}

test_port_connection() {
    local hostname="$1"
    local port="$2"
    local timeout="${3:-5}"
    
    timeout $timeout bash -c "echo >/dev/tcp/$hostname/$port" 2>/dev/null
    return $?
}

test_valid_ip() {
    local ip="$1"
    
    if [[ "$ip" == "localhost" ]] || [[ "$ip" == "127.0.0.1" ]]; then
        return 0
    fi
    
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local IFS='.'
        read -r i1 i2 i3 i4 <<< "$ip"
        if (( i1 <= 255 && i2 <= 255 && i3 <= 255 && i4 <= 255 )); then
            return 0
        fi
    fi
    return 1
}

test_ping() {
    local hostname="$1"
    
    if ping -c 1 -W 2 "$hostname" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Limpar tela
clear

# Cabecalho
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}        TESTADOR DE CONEXAO DE PORTAS     ${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

write_log "=== INICIO DO TESTE DE CONEXAO ==="

# Para testar multiplas portas
porta=0
continuar=""

while true; do
    # IP
    echo ""
    read -p "Digite o IP ou hostname para testar (ou 'sair' para encerrar): " hostname
    
    if [[ "$hostname" == "sair" ]]; then
        break
    fi
    
    # Solicita a porta
    while true; do
        read -p "Digite o numero da porta (ou 'voltar' para mudar de IP): " porta_input
        
        if [[ "$porta_input" == "voltar" ]]; then
            break 2
        fi
        
        # Validacao
        if [[ "$porta_input" =~ ^[0-9]+$ ]] && (( porta_input >= 1 && porta_input <= 65535 )); then
            porta=$porta_input
            break
        else
            write_log "Porta invalida: $porta_input" "ERRO"
            show_notification "Erro" "Porta invalida. Digite um numero valido." "Error"
        fi
    done
    
    echo ""
    echo -e "${YELLOW}=========================================${NC}"
    echo -e "${YELLOW}TESTANDO CONEXAO: $hostname : $porta${NC}"
    echo -e "${YELLOW}=========================================${NC}"
    
    write_log "Testando conexao: $hostname na porta $porta"
    
    # Faz teste de ping
    echo ""
    echo -e "${GRAY}Testando ping...${NC}"
    
    if test_ping "$hostname"; then
        echo -e "${GREEN}✅ Ping: SUCESSO - Host respondeu${NC}"
        write_log "Ping: SUCESSO - Host respondeu"
    else
        echo -e "${YELLOW}❌ Ping: FALHA - Host nao respondeu${NC}"
        write_log "Ping: FALHA - Host nao respondeu" "AVISO"
    fi
    
    # Testa a porta
    echo ""
    echo -e "${GRAY}Testando porta $porta...${NC}"
    
    start_time=$(date +%s%N)
    if test_port_connection "$hostname" "$porta" 5; then
        end_time=$(date +%s%N)
        elapsed=$(( ($end_time - $start_time) / 1000000 ))
        
        echo -e "${GREEN}✅ Porta $porta: ABERTA - Conexao estabelecida (${elapsed}ms)${NC}"
        write_log "Porta $porta: ABERTA - Conexao estabelecida (${elapsed}ms)" "SUCESSO"
        
        status_msg="✅ Porta $porta ABERTA em $hostname (${elapsed}ms)"
        show_notification "Conexao Bem Sucedida" "$status_msg" "Info"
    else
        echo -e "${RED}❌ Porta $porta: FECHADA/FILTRADA - Nao foi possivel conectar${NC}"
        write_log "Porta $porta: FECHADA/FILTRADA - Nao foi possivel conectar" "ERRO"
        
        status_msg="❌ Porta $porta FECHADA/FILTRADA em $hostname"
        show_notification "Falha na Conexao" "$status_msg" "Error"
    fi
    
    # Opcao de testar outra porta no mesmo host
    echo ""
    read -p "Deseja testar outra porta no mesmo host? (S/N): " continuar
    
    if [[ ! "$continuar" =~ ^[Ss]$ ]]; then
        break
    fi
done

write_log "=== FIM DO TESTE DE CONEXAO ==="
write_log ""

echo ""
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}           TESTES FINALIZADOS             ${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
echo -e "${GREEN}Log dos testes salvo em: $LOG_FILE${NC}"
echo ""

# Resumo
if [ -f "$LOG_FILE" ]; then
    echo -e "${YELLOW}Ultimos testes realizados:${NC}"
    echo ""
    
    tail -n 10 "$LOG_FILE" | while IFS= read -r linha; do
        if [[ $linha == *"SUCESSO"* ]]; then
            echo -e "${GREEN}$linha${NC}"
        elif [[ $linha == *"ERRO"* ]]; then
            echo -e "${RED}$linha${NC}"
        elif [[ $linha == *"AVISO"* ]]; then
            echo -e "${YELLOW}$linha${NC}"
        else
            echo -e "${GRAY}$linha${NC}"
        fi
    done
fi

echo ""
echo -e "${GRAY}Pressione qualquer tecla para sair...${NC}"
read -n 1 -s




















