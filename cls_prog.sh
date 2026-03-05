#
# Script em Bash que efetua a limpeza de arquivos temporários e da lixeira e salva a atividade em arquivo txt.
# Por padrão está definido manter arquivos com 30 dias ou menos
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x cls_prog.sh
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
# ./cls_prog.sh
#
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab
#
#!/bin/bash

# Configuracoes
LIMPAR_LIXEIRA=true  # Altere para false se nao quiser limpar a lixeira
LIMPAR_TEMP=true     # Altere para false se nao quiser limpar temporarios
LIMPAR_CACHE=true    # Altere para false se nao quiser limpar caches
LIMPAR_LOGS=true     # Altere para false se nao quiser limpar logs
DIAS_PARA_MANTER=30  # Arquivos temporarios mais antigos que isso serao deletados
LOG_DIR="$HOME/HistoricoLimpeza"
LOG_FILE="$LOG_DIR/Limpeza_$(date +'%Y-%m-%d').log"
DATA_HORA_INICIO=$(date +"%d/%m/%Y %H:%M:%S")

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Criar diretorio de log se necessario
mkdir -p "$LOG_DIR"

# Funcoes
write_log() {
    local message="$1"
    local status="${2:-INFO}"
    local timestamp=$(date +"%d/%m/%Y %H:%M:%S")
    echo "$timestamp | $status | $message" >> "$LOG_FILE"
}

format_file_size() {
    local bytes=$1
    if [ $bytes -gt $((1024**4)) ]; then
        echo "$(echo "scale=2; $bytes/1024^4" | bc) TB"
    elif [ $bytes -gt $((1024**3)) ]; then
        echo "$(echo "scale=2; $bytes/1024^3" | bc) GB"
    elif [ $bytes -gt $((1024**2)) ]; then
        echo "$(echo "scale=2; $bytes/1024^2" | bc) MB"
    elif [ $bytes -gt 1024 ]; then
        echo "$(echo "scale=2; $bytes/1024" | bc) KB"
    else
        echo "$bytes B"
    fi
}

get_folder_size() {
    local folder="$1"
    if [ -d "$folder" ]; then
        du -sb "$folder" 2>/dev/null | cut -f1
    else
        echo 0
    fi
}

clear_folder() {
    local folder="$1"
    local description="$2"
    local days_old="${3:-0}"
    
    local espaco_liberado=0
    local arquivos_removidos=0
    
    if [ -d "$folder" ]; then
        echo -e "${YELLOW}Limpando $description...${NC}"
        write_log "Iniciando limpeza de $description"
        
        if [ $days_old -gt 0 ]; then
            # Remove arquivos mais antigos que o valor da variavel DIAS_PARA_MANTER
            arquivos=$(find "$folder" -type f -mtime +$days_old 2>/dev/null)
            for arquivo in $arquivos; do
                if [ -f "$arquivo" ]; then
                    size=$(stat -c%s "$arquivo" 2>/dev/null)
                    espaco_liberado=$((espaco_liberado + size))
                    rm -f "$arquivo" 2>/dev/null
                    arquivos_removidos=$((arquivos_removidos + 1))
                fi
            done
            
            # Remove diretorios vazios
            find "$folder" -type d -empty -delete 2>/dev/null
        else
            # Remove tudo
            size_before=$(get_folder_size "$folder")
            rm -rf "${folder:?}"/* 2>/dev/null
            rm -rf "${folder:?}"/.* 2>/dev/null
            size_after=$(get_folder_size "$folder")
            espaco_liberado=$((size_before - size_after))
            arquivos_removidos=-1 # Indicador que removeu tudo
        fi
        
        write_log "Limpeza de $description concluida" "SUCESSO"
        echo "$arquivos_removidos:$espaco_liberado"
    else
        echo "0:0"
    fi
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${YELLOW}Aviso: $1 não está instalado. Pulando limpeza relacionada...${NC}"
        return 1
    fi
    return 0
}

# Limpa a tela
clear

# Cabecalho
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}    INICIANDO LIMPEZA DO SISTEMA        ${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

write_log "=== INICIO DA LIMPEZA ==="
write_log "Configuracoes:"
write_log "  - Limpar Lixeira: $LIMPAR_LIXEIRA"
write_log "  - Limpar Temporarios: $LIMPAR_TEMP"
write_log "  - Limpar Cache: $LIMPAR_CACHE"
write_log "  - Limpar Logs: $LIMPAR_LOGS"
write_log "  - Dias para manter: $DIAS_PARA_MANTER"

# Inicializa contadores
TOTAL_ESPACO_LIBERADO=0
TOTAL_ARQUIVOS_REMOVIDOS=0

# Mostra espaco em disco antes da limpeza
echo -e "${GRAY}Espaco em disco antes da limpeza:${NC}"
df -h / | tail -1 | awk '{print "   Disponivel: " $4 " de " $2}'
echo ""

TEMPO_INICIO=$(date +%s)

# 1. Limpeza da Lixeira
if [ "$LIMPAR_LIXEIRA" = true ]; then
    echo -e "${GREEN}Limpando Lixeira...${NC}"
    
    # Lixeira do usuario (diferentes ambientes desktop)
    lixeiras=(
        "$HOME/.local/share/Trash"
        "$HOME/.trash"
    )
    
    for lixeira in "${lixeiras[@]}"; do
        if [ -d "$lixeira" ]; then
            size_before=$(get_folder_size "$lixeira")
            rm -rf "$lixeira"/{files,info,expunged} 2>/dev/null
            echo -e "  ${GREEN}✅ Lixeira limpa com sucesso${NC}"
            write_log "Lixeira limpa com sucesso" "SUCESSO"
            TOTAL_ARQUIVOS_REMOVIDOS=$((TOTAL_ARQUIVOS_REMOVIDOS + 100))  # Estimativa
        fi
    done
fi

# 2. Limpeza de Arquivos Temporarios
if [ "$LIMPAR_TEMP" = true ]; then
    echo -e "${GREEN}Limpando Arquivos Temporarios...${NC}"
    
    temp_paths=(
        "/tmp"
        "/var/tmp"
        "$HOME/tmp"
        "$HOME/.cache"
    )
    
    for path in "${temp_paths[@]}"; do
        resultado=$(clear_folder "$path" "Temporarios: $path" "$DIAS_PARA_MANTER")
        arquivos=$(echo $resultado | cut -d: -f1)
        espaco=$(echo $resultado | cut -d: -f2)
        
        if [ "$arquivos" != "0" ] || [ "$espaco" != "0" ]; then
            TOTAL_ARQUIVOS_REMOVIDOS=$((TOTAL_ARQUIVOS_REMOVIDOS + arquivos))
            TOTAL_ESPACO_LIBERADO=$((TOTAL_ESPACO_LIBERADO + espaco))
        fi
    done
fi

# 3. Limpeza de Caches
if [ "$LIMPAR_CACHE" = true ]; then
    echo -e "${GREEN}Limpando Caches...${NC}"
    
    # Cache do APT (Debian/Ubuntu)
    if check_command "apt-get"; then
        echo "  Limpando cache do APT..."
        size_before=$(du -s /var/cache/apt/archives 2>/dev/null | cut -f1)
        apt-get clean 2>/dev/null
        write_log "Cache do APT limpo" "SUCESSO"
    fi
    
    # Cache do DNF (Fedora)
    if check_command "dnf"; then
        echo "  Limpando cache do DNF..."
        dnf clean all 2>/dev/null
        write_log "Cache do DNF limpo" "SUCESSO"
    fi
    
    # Cache do Pacman (Arch)
    if check_command "pacman"; then
        echo "  Limpando cache do Pacman..."
        pacman -Sc --noconfirm 2>/dev/null
        write_log "Cache do Pacman limpo" "SUCESSO"
    fi
    
    # Cache de miniaturas
    thumb_cache="$HOME/.thumbnails"
    if [ -d "$thumb_cache" ]; then
        resultado=$(clear_folder "$thumb_cache" "Cache de Miniaturas")
        arquivos=$(echo $resultado | cut -d: -f1)
        espaco=$(echo $resultado | cut -d: -f2)
        TOTAL_ARQUIVOS_REMOVIDOS=$((TOTAL_ARQUIVOS_REMOVIDOS + arquivos))
        TOTAL_ESPACO_LIBERADO=$((TOTAL_ESPACO_LIBERADO + espaco))
    fi
fi

# 4. Limpeza de Logs
if [ "$LIMPAR_LOGS" = true ]; then
    echo -e "${GREEN}Limpando Logs do Sistema...${NC}"
    
    log_paths=(
        "/var/log"
        "$HOME/.logs"
    )
    
    for path in "${log_paths[@]}"; do
        if [ -d "$path" ]; then
            # Roda find como sudo para logs do sistema
            if [[ "$path" == "/var/log" ]]; then
                sudo find "$path" -type f -name "*.log" -mtime +$DIAS_PARA_MANTER -delete 2>/dev/null
                sudo find "$path" -type f -name "*.gz" -mtime +$DIAS_PARA_MANTER -delete 2>/dev/null
                sudo find "$path" -type f -name "*.old" -mtime +$DIAS_PARA_MANTER -delete 2>/dev/null
            else
                find "$path" -type f -name "*.log" -mtime +$DIAS_PARA_MANTER -delete 2>/dev/null
                find "$path" -type f -name "*.gz" -mtime +$DIAS_PARA_MANTER -delete 2>/dev/null
                find "$path" -type f -name "*.old" -mtime +$DIAS_PARA_MANTER -delete 2>/dev/null
            fi
            echo -e "  ${GREEN}✅ Logs antigos removidos de $path${NC}"
            write_log "Logs antigos removidos de $path" "SUCESSO"
        fi
    done
    
    # Limpa logs do journal (systemd)
    if check_command "journalctl"; then
        echo "  Limpando logs do journal (ultimos $DIAS_PARA_MANTER dias)..."
        sudo journalctl --vacuum-time=${DIAS_PARA_MANTER}d 2>/dev/null
        write_log "Logs do journal limpos" "SUCESSO"
    fi
fi

# 5. Limpeza de Cache de Navegadores
echo -e "${GREEN}Limpando Caches de Navegadores...${NC}"

# Firefox
firefox_cache="$HOME/.cache/mozilla/firefox"
if [ -d "$firefox_cache" ]; then
    resultado=$(clear_folder "$firefox_cache" "Cache Firefox")
    arquivos=$(echo $resultado | cut -d: -f1)
    espaco=$(echo $resultado | cut -d: -f2)
    TOTAL_ARQUIVOS_REMOVIDOS=$((TOTAL_ARQUIVOS_REMOVIDOS + arquivos))
    TOTAL_ESPACO_LIBERADO=$((TOTAL_ESPACO_LIBERADO + espaco))
fi

# Chrome/Chromium
chrome_cache="$HOME/.cache/google-chrome"
if [ -d "$chrome_cache" ]; then
    resultado=$(clear_folder "$chrome_cache" "Cache Chrome")
    arquivos=$(echo $resultado | cut -d: -f1)
    espaco=$(echo $resultado | cut -d: -f2)
    TOTAL_ARQUIVOS_REMOVIDOS=$((TOTAL_ARQUIVOS_REMOVIDOS + arquivos))
    TOTAL_ESPACO_LIBERADO=$((TOTAL_ESPACO_LIBERADO + espaco))
fi

# Brave
brave_cache="$HOME/.cache/Brave-Browser"
if [ -d "$brave_cache" ]; then
    resultado=$(clear_folder "$brave_cache" "Cache Brave")
    arquivos=$(echo $resultado | cut -d: -f1)
    espaco=$(echo $resultado | cut -d: -f2)
    TOTAL_ARQUIVOS_REMOVIDOS=$((TOTAL_ARQUIVOS_REMOVIDOS + arquivos))
    TOTAL_ESPACO_LIBERADO=$((TOTAL_ESPACO_LIBERADO + espaco))
fi

# 6. Limpeza de Pacotes Desnecessarios
echo -e "${GREEN}Removendo pacotes desnecessarios...${NC}"

if check_command "apt-get"; then
    echo "  Removendo pacotes orfaos (Debian/Ubuntu)..."
    apt-get autoremove --purge -y 2>/dev/null
    apt-get autoclean 2>/dev/null
    write_log "Pacotes orfaos removidos" "SUCESSO"
fi

if check_command "dnf"; then
    echo "  Removendo pacotes orfaos (Fedora)..."
    dnf autoremove -y 2>/dev/null
    write_log "Pacotes orfaos removidos" "SUCESSO"
fi

if check_command "pacman"; then
    echo "  Removendo pacotes orfaos (Arch)..."
    pacman -Qdtq | pacman -Rs - 2>/dev/null
    write_log "Pacotes orfaos removidos" "SUCESSO"
fi

# Calcula tempo total
TEMPO_FIM=$(date +%s)
TEMPO_TOTAL=$((TEMPO_FIM - TEMPO_INICIO))
MINUTOS=$((TEMPO_TOTAL / 60))
SEGUNDOS=$((TEMPO_TOTAL % 60))

# Mostra espaco em disco
echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}        LIMPEZA CONCLUIDA COM SUCESSO     ${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

echo -e "${WHITE}Resumo da Limpeza:${NC}"
echo -e "   ${GRAY}Arquivos removidos: $TOTAL_ARQUIVOS_REMOVIDOS${NC}"
echo -e "   ${GRAY}Espaco liberado: $(format_file_size $TOTAL_ESPACO_LIBERADO)${NC}"
echo -e "   ${GRAY}Tempo total: ${MINUTOS}m ${SEGUNDOS}s${NC}"
echo ""

echo -e "${YELLOW}Espaco em disco apos limpeza:${NC}"
df -h / | tail -1 | awk '{print "   " $6 ": " $4 " livres"}'

# Log
write_log "=== LIMPEZA CONCLUIDA ==="
write_log "Arquivos removidos: $TOTAL_ARQUIVOS_REMOVIDOS"
write_log "Espaco liberado: $(format_file_size $TOTAL_ESPACO_LIBERADO)"
write_log "Tempo total: ${MINUTOS}m ${SEGUNDOS}s"

echo ""
echo -e "${GREEN}Log da limpeza salvo em: $LOG_FILE${NC}"
echo ""

# Mostra ultimas linhas do log
read -p "Deseja ver o log da limpeza? (s/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    if [ -f "$LOG_FILE" ]; then
        echo ""
        echo -e "${YELLOW}Ultimas 10 linhas do log:${NC}"
        tail -10 "$LOG_FILE"
    fi
fi

# Opcao para limpar completamente a lixeira
if [ "$LIMPAR_LIXEIRA" = true ]; then
    echo ""
    read -p "Deseja esvaziar completamente a Lixeira? (s/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        # Tenta diferentes implementacoes de limpeza de lixeira
        if [ -d "$HOME/.local/share/Trash" ]; then
            rm -rf "$HOME/.local/share/Trash"/{files,info,expunged} 2>/dev/null
            echo -e "${GREEN}✅ Lixeira esvaziada com sucesso!${NC}"
            write_log "Lixeira esvaziada completamente" "SUCESSO"
        elif command -v gio &> /dev/null; then
            gio trash --empty 2>/dev/null
            echo -e "${GREEN}✅ Lixeira esvaziada com sucesso!${NC}"
            write_log "Lixeira esvaziada completamente" "SUCESSO"
        else
            echo -e "${RED}❌ Nao foi possivel esvaziar a lixeira automaticamente${NC}"
        fi
    fi
fi

echo ""
echo -e "${GRAY}Pressione qualquer tecla para sair...${NC}"
read -n 1 -s -r