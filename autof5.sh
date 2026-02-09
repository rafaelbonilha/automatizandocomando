#
# Script em Bash para pressionar a tecla F5 a cada 25 segundos
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x autof5.sh
# 2-) Instale as dependencias.: 
#  Debian.:
#  sudo apt install xdotool
#
#  RHEL/CentOS/Fedora.:
#  sudo yum/dnf install xdotool
#
#  Arch.:
#  sudo pacman -S xdotool
#
#  MacOS - usando cliclick.:
#  brew install cliclick
#
# 3-) Casos de Uso.:
#
# Uso Basico.:
# ./autof5.sh
#
# # Com modificador (Ctrl+F5)
# ./autof5.sh -t F5 -o ctrl
#
# Com janela específica
# ./autof5.sh --janela "Firefox" --intervalo 30
#
# Com limite de execuções
# ./autof5.sh --max 10 --intervalo 10
#
# Modo silencioso com log
# ./autof5.sh -s -l /tmp/autokey.log
#
# Todas as opções
# ./autof5.sh -t F5 -o ctrlshift -i 60 -j "Chrome" -m 20 -l log.txt -d 3
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
#
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab#
#

#!/bin/bash

# Auto Key Press para Linux/macOS
# Dependências: xdotool (Linux) ou cliclick (macOS)

# Configurações padrão
TECLA="F5"
INTERVALO=25
DELAY_INICIAL=5
LOG_ARQUIVO=""
SILENCIOSO=0
CONTADOR_MAXIMO=0
JANELA_ALVO=""
MODIFICADOR="normal"
VERSAO="2.0"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Flags
PARAR=0
DATA_INICIO=$(date +%s)

# Verifica dependências
check_dependencies() {
    local missing_deps=()
    
    # Detecta sistema operacional
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        SISTEMA="linux"
        if ! command -v xdotool &> /dev/null; then
            missing_deps+=("xdotool")
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        SISTEMA="macos"
        if ! command -v cliclick &> /dev/null; then
            missing_deps+=("cliclick")
        fi
    else
        echo -e "${RED}Erro: Sistema operacional não suportado: $OSTYPE${NC}"
        exit 1
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}Atenção: As seguintes dependências estão faltando:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        fi
        echo ""
        
        if [ "$SISTEMA" = "linux" ]; then
            echo "Instale com: sudo apt-get install xdotool (Debian/Ubuntu)"
            echo "           ou sudo yum install xdotool (RHEL/CentOS)"
        elif [ "$SISTEMA" = "macos" ]; then
            echo "Instale com: brew install cliclick"
            echo "           ou baixe de: https://www.bluem.net/en/mac/cliclick/"
        fi
        exit 1
    fi
}

# Função para enviar tecla
enviar_tecla() {
    local tecla=$1
    local modificador=$2
    
    case "$SISTEMA" in
        "linux")
            # Mapeamento de modificadores para xdotool
            local mod_flags=""
            case "$modificador" in
                "alt") mod_flags="alt" ;;
                "ctrl") mod_flags="ctrl" ;;
                "shift") mod_flags="shift" ;;
                "altctrl") mod_flags="alt+ctrl" ;;
                "altshift") mod_flags="alt+shift" ;;
                "ctrlshift") mod_flags="ctrl+shift" ;;
                "altctrlshift") mod_flags="alt+ctrl+shift" ;;
            esac
            
            if [ -n "$mod_flags" ]; then
                xdotool keydown $mod_flags
                sleep 0.1
                xdotool key $tecla
                sleep 0.1
                xdotool keyup $mod_flags
            else
                xdotool key $tecla
            fi
            ;;
        "macos")
            # Mapeamento de modificadores para cliclick
            local mod_codes=""
            case "$modificador" in
                "alt") mod_codes="alt" ;;
                "ctrl") mod_codes="ctrl" ;;
                "shift") mod_codes="shift" ;;
                "altctrl") mod_codes="alt,ctrl" ;;
                "altshift") mod_codes="alt,shift" ;;
                "ctrlshift") mod_codes="ctrl,shift" ;;
                "altctrlshift") mod_codes="alt,ctrl,shift" ;;
            esac
            
            if [ -n "$mod_codes" ]; then
                cliclick kd:$mod_codes
                sleep 0.1
                cliclick k:$tecla
                sleep 0.1
                cliclick ku:$mod_codes
            else
                cliclick k:$tecla
            fi
            ;;
    esac
}

# Função para focar em janela
focar_janela() {
    local titulo="$1"
    
    if [ -z "$titulo" ]; then
        return 1
    fi
    
    case "$SISTEMA" in
        "linux")
            local window_id=$(xdotool search --name "$titulo" | head -1)
            if [ -n "$window_id" ]; then
                xdotool windowactivate "$window_id"
                sleep 0.5
                return 0
            fi
            ;;
        "macos")
            osascript -e "tell application \"System Events\" to set frontmost of every process whose name contains \"$titulo\" to true" 2>/dev/null
            sleep 0.5
            # Verifica se conseguiu focar
            local active_app=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null)
            if [[ "$active_app" == *"$titulo"* ]]; then
                return 0
            fi
            ;;
    esac
    
    return 1
}

# Função para obter janela ativa
get_janela_ativa() {
    case "$SISTEMA" in
        "linux")
            local window_id=$(xdotool getactivewindow)
            local window_title=$(xdotool getwindowname "$window_id" 2>/dev/null)
            echo "$window_title"
            ;;
        "macos")
            osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null
            ;;
    esac
}

# Função de logging
escrever_log() {
    local mensagem="$1"
    local tipo="${2:-INFO}"
    local cor="$WHITE"
    
    # Define cor baseada no tipo
    case "$tipo" in
        "ERRO") cor="$RED" ;;
        "ALERTA") cor="$YELLOW" ;;
        "SUCESSO") cor="$GREEN" ;;
        "INFO") cor="$WHITE" ;;
        "DEBUG") cor="$GRAY" ;;
    esac
    
    local hora=$(date "+%Y-%m-%d %H:%M:%S")
    local linha="[$hora][$tipo] $mensagem"
    
    # Escreve no console se não for silencioso
    if [ "$SILENCIOSO" -eq 0 ]; then
        echo -e "${cor}$linha${NC}"
    fi
    
    # Escreve no arquivo de log se especificado
    if [ -n "$LOG_ARQUIVO" ]; then
        echo "$linha" >> "$LOG_ARQUIVO"
    fi
}

# Função para mostrar ajuda
mostrar_ajuda() {
    echo -e "${CYAN}Auto Key Press v$VERSAO - Bash Script${NC}"
    echo "Uso: $0 [opções]"
    echo ""
    echo "Opções:"
    echo "  -t, --tecla TECLA        Tecla a pressionar (padrão: F5)"
    echo "  -i, --intervalo SEG      Intervalo em segundos (padrão: 25)"
    echo "  -d, --delay SEG          Delay inicial em segundos (padrão: 5)"
    echo "  -l, --log ARQUIVO        Arquivo de log (opcional)"
    echo "  -s, --silencioso         Executa sem output no console"
    echo "  -m, --max EXECUCOES      Número máximo de execuções (0 = infinito)"
    echo "  -j, --janela NOME        Focar em janela específica"
    echo "  -o, --modificador MOD    Modificador: normal, alt, ctrl, shift, etc."
    echo "  -h, --help               Mostra esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0 -t F5 -i 30"
    echo "  $0 --tecla F5 --modificador ctrl --janela Chrome"
    echo "  $0 -s -l /tmp/autokey.log -m 10"
}

# Tratador para Ctrl+C
trap_ctrl_c() {
    echo ""
    escrever_log "Recebido Ctrl+C — finalizando..." "ALERTA"
    PARAR=1
}

# Função para converter tempo
formatar_tempo() {
    local segundos=$1
    local dias=$((segundos / 86400))
    local horas=$(( (segundos % 86400) / 3600 ))
    local minutos=$(( (segundos % 3600) / 60 ))
    local segs=$((segundos % 60))
    
    if [ $dias -gt 0 ]; then
        printf "%d.%02d:%02d:%02d" $dias $horas $minutos $segs
    else
        printf "%02d:%02d:%02d" $horas $minutos $segs
    fi
}

# Parse de argumentos
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--tecla)
                TECLA="$2"
                shift 2
                ;;
            -i|--intervalo)
                INTERVALO="$2"
                shift 2
                ;;
            -d|--delay)
                DELAY_INICIAL="$2"
                shift 2
                ;;
            -l|--log)
                LOG_ARQUIVO="$2"
                shift 2
                ;;
            -s|--silencioso)
                SILENCIOSO=1
                shift
                ;;
            -m|--max)
                CONTADOR_MAXIMO="$2"
                shift 2
                ;;
            -j|--janela)
                JANELA_ALVO="$2"
                shift 2
                ;;
            -o|--modificador)
                MODIFICADOR="$2"
                shift 2
                ;;
            -h|--help)
                mostrar_ajuda
                exit 0
                ;;
            *)
                echo -e "${RED}Erro: Opção desconhecida: $1${NC}"
                mostrar_ajuda
                exit 1
                ;;
        esac
    done
}

# Configuração do log
setup_log() {
    if [ -n "$LOG_ARQUIVO" ]; then
        # Cria diretório se não existir
        local log_dir=$(dirname "$LOG_ARQUIVO")
        if [ -n "$log_dir" ] && [ ! -d "$log_dir" ]; then
            mkdir -p "$log_dir"
        fi
        
        # Cria arquivo de log vazio
        > "$LOG_ARQUIVO"
    fi
}

# Main
main() {
    # Verifica dependências
    check_dependencies
    
    # Parse argumentos
    parse_args "$@"
    
    # Configura trap para Ctrl+C
    trap trap_ctrl_c SIGINT SIGTERM
    
    # Configura log
    setup_log
    
    # Mostra informações iniciais
    if [ "$SILENCIOSO" -eq 0 ]; then
        echo -e "${CYAN}\n=== Auto Key Press v$VERSAO ===${NC}"
        echo -e "${WHITE}Tecla: $TECLA"
        echo "Modificador: $MODIFICADOR"
        echo "Intervalo: $INTERVALO segundos"
        echo "Delay inicial: $DELAY_INICIAL segundos"
        if [ -n "$JANELA_ALVO" ]; then echo "Janela alvo: $JANELA_ALVO"; fi
        if [ "$CONTADOR_MAXIMO" -gt 0 ]; then echo "Máximo de execuções: $CONTADOR_MAXIMO"; fi
        echo "Log: ${LOG_ARQUIVO:-Nenhum}"
        echo -e "\nPressione Ctrl+C para parar${NC}\n"
    fi
    
    # Delay inicial
    if [ "$DELAY_INICIAL" -gt 0 ]; then
        escrever_log "Iniciando em $DELAY_INICIAL segundos..." "INFO"
        for ((i=DELAY_INICIAL; i>0 && PARAR==0; i--)); do
            if [ "$SILENCIOSO" -eq 0 ] && [ $((i % 5)) -eq 0 ] && [ $i -gt 0 ]; then
                echo -e "${GRAY}  Iniciando em $i segundos...${NC}"
            fi
            sleep 1
        done
    fi
    
    if [ "$PARAR" -eq 1 ]; then
        escrever_log "Script cancelado durante delay inicial" "ALERTA"
        return
    fi
    
    # Loop principal
    local contador=0
    local primeira_execucao=1
    
    while [ "$PARAR" -eq 0 ]; do
        # Verifica limite de execuções
        if [ "$CONTADOR_MAXIMO" -gt 0 ] && [ "$contador" -ge "$CONTADOR_MAXIMO" ]; then
            escrever_log "Limite de $CONTADOR_MAXIMO execuções atingido" "INFO"
            break
        fi
        
        ((contador++))
        
        # Foca na janela alvo se especificada
        if [ -n "$JANELA_ALVO" ] && { [ "$primeira_execucao" -eq 1 ] || [ "$INTERVALO" -gt 60 ]; }; then
            if focar_janela "$JANELA_ALVO"; then
                escrever_log "Janela focada: $JANELA_ALVO" "SUCESSO"
                sleep 0.5
            else
                escrever_log "Não foi possível focar na janela: $JANELA_ALVO" "ALERTA"
            fi
            primeira_execucao=0
        fi
        
        # Obtém informações da janela ativa
        local janela_ativa=$(get_janela_ativa)
        local info_janela=""
        if [ -n "$janela_ativa" ]; then
            info_janela=" (Janela: '${janela_ativa:0:50}')"
        fi
        
        # Envia a tecla
        escrever_log "Enviando: $TECLA com modificador $MODIFICADOR - Execução #$contador$info_janela" "INFO"
        
        if enviar_tecla "$TECLA" "$MODIFICADOR"; then
            escrever_log "Tecla enviada com sucesso" "SUCESSO"
        else
            escrever_log "Erro ao enviar tecla" "ERRO"
        fi
        
        # Aguarda o intervalo (com tratamento de Ctrl+C)
        if [ "$contador" -lt "$CONTADOR_MAXIMO" ] || [ "$CONTADOR_MAXIMO" -eq 0 ]; then
            local segundos_restantes=$INTERVALO
            
            while [ "$segundos_restantes" -gt 0 ] && [ "$PARAR" -eq 0 ]; do
                sleep 1
                ((segundos_restantes--))
                
                # Mostra contagem regressiva a cada 5 segundos
                if [ "$SILENCIOSO" -eq 0 ] && [ $((segundos_restantes % 5)) -eq 0 ] && [ "$segundos_restantes" -gt 0 ]; then
                    local tempo_decorrido=$(( $(date +%s) - DATA_INICIO ))
                    local tempo_formatado=$(formatar_tempo $tempo_decorrido)
                    echo -e "${GRAY}  Próxima execução em $segundos_restantes segundos (Tempo total: $tempo_formatado)${NC}"
                fi
            done
            
            if [ "$PARAR" -eq 0 ] && [ "$segundos_restantes" -eq 0 ]; then
                escrever_log "Aguardando próximo ciclo..." "DEBUG"
            fi
        fi
    done
    
    # Estatísticas finais
    local tempo_total=$(( $(date +%s) - DATA_INICIO ))
    local tempo_total_formatado=$(formatar_tempo $tempo_total)
    local intervalo_medio=0
    if [ "$contador" -gt 1 ]; then
        intervalo_medio=$(echo "scale=2; $tempo_total / ($contador - 1)" | bc)
    fi
    
    escrever_log "========================================" "INFO"
    escrever_log "SCRIPT FINALIZADO" "INFO"
    escrever_log "Total de execuções: $contador" "INFO"
    escrever_log "Tempo total: $tempo_total_formatado" "INFO"
    escrever_log "Tecla enviada: $TECLA ($MODIFICADOR)" "INFO"
    escrever_log "Intervalo médio: $intervalo_medio segundos" "INFO"
    
    if [ -n "$LOG_ARQUIVO" ]; then
        escrever_log "Log salvo em: $LOG_ARQUIVO" "INFO"
    fi
    
    escrever_log "========================================" "INFO"
    
    # Aguarda um pouco antes de fechar
    if [ "$SILENCIOSO" -eq 0 ]; then
        sleep 2
    fi
}

# Executa main
main "$@"
