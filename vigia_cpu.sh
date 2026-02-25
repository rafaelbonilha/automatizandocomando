#
# Script em Bash que irá mostrar os 10 processos que mais consomem CPU
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x vigia_cpu.sh
#
# 2-) Como usar.:
#
# Uso Basico.:
# ./vigia_cpu.sh
#
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab#
#
#!/bin/bash

# Variaveis de Data e Hora e Log
LOG_DIR="/tmp/logs"
LOG_PATH="$LOG_DIR/HistoricoCPU.txt"
DATA_HORA=$(date '+%d/%m/%Y %H:%M:%S')

# Cria diretorio do log se necessario
mkdir -p "$LOG_DIR"


log() {
    local message="$1"
    local color="$2"
    
    echo "$(date '+%d/%m/%Y %H:%M:%S') - $message" >> "$LOG_PATH"
    
    if [ -n "$color" ]; then
        echo -e "${color}$message\e[0m"
    else
        echo "$message"
    fi
}

clear

echo -e "\e[36m=========================================\e[0m"
echo -e "\e[36m    TOP 10 PROCESSOS - CONSUMO DE CPU    \e[0m"
echo -e "\e[36m=========================================\e[0m"
echo ""

# Registra no log
echo "=========================================" >> "$LOG_PATH"
echo "$DATA_HORA - TOP 10 PROCESSOS CPU" >> "$LOG_PATH"

# Obtem os top 10 processos por consumo de CPU
PROCESSOS=$(ps aux --sort=-%cpu | head -11 | tail -10 | awk '{print $11, $2, $3, $4, $6}')

if [ -n "$PROCESSOS" ]; then
    printf "\e[1m%-30s %-10s %-10s %-10s %-10s\e[0m\n" "PROCESSO" "PID" "CPU(%)" "MEM(%)" "MEM(KB)"
    echo "------------------------------------------------------------------------------"
    
    TOTAL_CPU=0
    TOP_PROCESSO=""
    TOP_PID=""
    TOP_CPU=0
    
    while IFS= read -r linha; do
        # Extrai os campos 
        NOME=$(echo "$linha" | awk '{print $1}')
        PID=$(echo "$linha" | awk '{print $2}')
        CPU=$(echo "$linha" | awk '{print $3}')
        MEM_PERCENT=$(echo "$linha" | awk '{print $4}')
        MEM_KB=$(echo "$linha" | awk '{print $5}')
        
        # Converte KB para MB
        MEM_MB=$(echo "scale=2; $MEM_KB / 1024" | bc 2>/dev/null || echo "0")
        
        # Formata para exibir
        printf "%-30s %-10s %-10s %-10s %-10s\n" "$NOME" "$PID" "$CPU" "$MEM_PERCENT" "${MEM_MB}MB"
        
        echo "$DATA_HORA | Processo: $NOME | PID: $PID | CPU: $CPU% | Memoria: ${MEM_MB}MB" >> "$LOG_PATH"
        
        # Acumula total de CPU (para o top 10)
        TOTAL_CPU=$(echo "$TOTAL_CPU + $CPU" | bc 2>/dev/null || echo "$TOTAL_CPU")
        
        # Identifica o processo com maior consumo
        if (( $(echo "$CPU > $TOP_CPU" | bc -l 2>/dev/null || echo "0") )); then
            TOP_CPU=$CPU
            TOP_PROCESSO=$NOME
            TOP_PID=$PID
        fi
    done <<< "$PROCESSOS"
    
    echo "------------------------------------------------------------------------------"
    
    TOTAL_CPU_FORMAT=$(echo "$TOTAL_CPU" | bc 2>/dev/null || echo "0")
    echo -e "\e[33mTotal CPU (top 10): $TOTAL_CPU_FORMAT%\e[0m"
    echo "$DATA_HORA | TOTAL CPU (top 10): $TOTAL_CPU_FORMAT%" >> "$LOG_PATH"
    
    if [ -n "$TOP_PROCESSO" ]; then
        echo -e "\e[32mProcesso com maior consumo: $TOP_PROCESSO (PID: $TOP_PID) - ${TOP_CPU}%\e[0m"
    fi
    
    # Verifica se existe alerta (CPU > 75%)
    if (( $(echo "$TOP_CPU > 80" | bc -l 2>/dev/null || echo "0") )); then
        echo -e "\e[31m⚠️  ALERTA: Processo $TOP_PROCESSO esta consumindo ${TOP_CPU}% de CPU!\e[0m"
        echo "$DATA_HORA | ALERTA: Processo $TOP_PROCESSO consumindo ${TOP_CPU}% de CPU" >> "$LOG_PATH"
    fi
    
else
    echo -e "\e[31mNenhum processo com consumo significativo de CPU encontrado.\e[0m"
    echo "$DATA_HORA | Nenhum processo com consumo significativo encontrado" >> "$LOG_PATH"
fi

echo "" >> "$LOG_PATH"
echo ""
echo -e "\e[90mMonitoramento concluido em: $(date '+%d/%m/%Y %H:%M:%S')\e[0m"
echo -e "\e[32mLog salvo em: $LOG_PATH\e[0m"

# Exibe ultimas linhas do log
echo ""
echo -e "\e[90mUltimas entradas do log:\e[0m"
tail -5 "$LOG_PATH"