#
# Script em Bash que irá mostrar os 10 processos que mais consomem Rede, avisar se passar de 75% e registrar em arquivo de log
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x consumernet.sh
#
# 2-) Execute com o comando sudo para ver todos os processos.:
#   sudo ./consumernet.sh
#
# 3-) Instale as dependencias.:
#
#  Debian.:
#  sudo apt install netstat ss notify-send
#
#  RHEL/CentOS/Fedora.:
#  sudo dnf install netstat ss notify-send ou
#  sudo yum install netstat ss notify-send (CentOS)
#
# Uso Basico.:
# ./consumernet.sh
#
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab#
#
#!/bin/bash

LOG_DIR="$HOME"
LOG_FILE="$LOG_DIR/HistoricoRede.txt"
DATA_HORA=$(date '+%d/%m/%Y %H:%M:%S')

# Criar diretorio de log se nao existir
mkdir -p "$LOG_DIR"

# Funcao para obter estatisticas de rede por processo
get_network_stats() {
    # Limpa arquivos temporários
    TEMP_FILE=$(mktemp)
    TEMP_PROCESSES=$(mktemp)
    
    # Obtem todas as conexões TCP estabelecidas usando netstat
    if command -v netstat &> /dev/null; then
        # Linux com netstat
        netstat -tunp 2>/dev/null | grep ESTABLISHED | awk '{print $7,$4,$5}' | sed 's/:[0-9]*//g' > "$TEMP_FILE"
    elif command -v ss &> /dev/null; then
        # Linux com ss 
        ss -tunp state established 2>/dev/null | awk 'NR>1 {print $6,$4,$5}' | sed 's/:[0-9]*//g; s/users:(("//g; s/",.*//g' > "$TEMP_FILE"
    else
        echo "Erro: netstat ou ss nao encontrado. Instale net-tools ou iproute2."
        return 1
    fi
    
    # Processa cada conexao
    declare -A processos
    
    while read line; do
        if [ ! -z "$line" ]; then
            # Extrai PID, endereco local e remoto
            pid=$(echo "$line" | awk '{print $1}' | grep -o '[0-9]*' | head -1)
            local_addr=$(echo "$line" | awk '{print $2}')
            remote_addr=$(echo "$line" | awk '{print $3}')
            
            if [ ! -z "$pid" ] && [ "$pid" != "-" ] && [ "$pid" -gt 0 ] 2>/dev/null; then
               
                if [ -e "/proc/$pid/comm" ]; then
                    process_name=$(cat /proc/$pid/comm 2>/dev/null | head -1)
                else
                    process_name=$(ps -p $pid -o comm= 2>/dev/null)
                fi
                
                if [ ! -z "$process_name" ]; then
                    # Inicializa ou atualiza contador
                    if [ -z "${processos[$pid]}" ]; then
                        process_name_clean=$(echo "$process_name" | head -c 30)
                        processos[$pid]="$process_name_clean:1:$remote_addr"
                    else
                        IFS=':' read -r name conns addrs <<< "${processos[$pid]}"
                        conns=$((conns + 1))
                        if [[ "$addrs" != *"$remote_addr"* ]]; then
                            addrs="$addrs,$remote_addr"
                        fi
                        processos[$pid]="$name:$conns:$addrs"
                    fi
                fi
            fi
        fi
    done < "$TEMP_FILE"
    
    # Converte para formato de saada
    for pid in "${!processos[@]}"; do
        IFS=':' read -r name conns addrs <<< "${processos[$pid]}"
        banda=$(echo "scale=2; $conns * 0.1" | bc 2>/dev/null || echo "0")
        
        # Limita numero de enderecos para exibicao
        addrs_count=$(echo "$addrs" | tr ',' '\n' | wc -l)
        if [ "$addrs_count" -gt 3 ]; then
            addrs=$(echo "$addrs" | cut -d',' -f1-3)
            addrs="$addrs..."
        fi
        
        echo "$pid:$name:$conns:$banda:$addrs"
    done | sort -t':' -k3 -rn | head -10
    
    # Limpa arquivos temporarios
    rm -f "$TEMP_FILE" "$TEMP_PROCESSES"
}

# Funcao para exibir notificacao (opcional se instalado o notify-send)
show_notification() {
    local title="$1"
    local message="$2"
    
    if command -v notify-send &> /dev/null; then
        notify-send --urgency=critical "$title" "$message"
    elif command -v osascript &> /dev/null; then
        # macOS
        osascript -e "display notification \"$message\" with title \"$title\""
    else
        echo "🔔 NOTIFICACAO: $title - $message"
    fi
}

clear

echo "==============================================="
echo "   TOP 10 PROCESSOS - CONSUMO DE BANDA DE REDE   "
echo "==============================================="
echo ""

echo "Coletando informacoes de rede..." 

# Obtem estatisticas
network_stats=$(get_network_stats)

# Registra no log
echo "===============================================" >> "$LOG_FILE"
echo "$DATA_HORA - TOP 10 PROCESSOS - BANDA DE REDE" >> "$LOG_FILE"
echo "===============================================" >> "$LOG_FILE"

if [ ! -z "$network_stats" ]; then
    printf "%-25s %-10s %-12s %-15s %s\n" "PROCESSO" "PID" "CONEXOES" "BANDA(Mbps)" "PRINCIPAIS DESTINOS"
    printf "%-25s %-10s %-12s %-15s %s\n" "-------" "---" "--------" "-----------" "------------------"
    
    total_banda=0
    total_conexoes=0
    first_process=""
    first_pid=""
    first_conns=0
    first_banda=0
    
    # Processa cada linha
    while IFS=':' read -r pid name conns banda addrs; do
        # Formata a saida
        name=$(echo "$name" | head -c 22)
        printf "%-25s %-10s %-12s %-15s %s\n" "$name" "$pid" "$conns" "$banda" "$addrs"
        
        # Para o log
        echo "$DATA_HORA | Processo: $name | PID: $pid | Conexoes: $conns | Banda: $banda Mbps | Destinos: $addrs" >> "$LOG_FILE"
        
        # Acumula totais
        total_conexoes=$((total_conexoes + conns))
        total_banda=$(echo "scale=2; $total_banda + $banda" | bc 2>/dev/null || echo "0")
        
        # Salva primeiro processo (maior consumo)
        if [ -z "$first_process" ]; then
            first_process="$name"
            first_pid="$pid"
            first_conns="$conns"
            first_banda="$banda"
        fi
    done <<< "$network_stats"
    
    echo ""
    echo "Total Banda Estimada (top 10): $total_banda Mbps"
    echo "Total Conexões Ativas (top 10): $total_conexoes"
    
    echo "$DATA_HORA | TOTAL BANDA ESTIMADA (top 10): $total_banda Mbps" >> "$LOG_FILE"
    echo "$DATA_HORA | TOTAL CONEXOES (top 10): $total_conexoes" >> "$LOG_FILE"
    
    # Destaque para o processo de maior consumo
    echo ""
    echo -e "Processo com maior consumo: \033[1;32m$first_process (PID: $first_pid)\033[0m"
    echo "Conexoes ativas: $first_conns | Banda estimada: $first_banda Mbps"
    
    # Alerta se consumo for muito alto
    if [ "$first_conns" -gt 75 ]; then
        echo ""
        echo -e "\033[1;37;41m⚠️  ALERTA: Processo $first_process tem muitas conexoes ativas!\033[0m"
        echo "$DATA_HORA | ⚠️ ALERTA: Processo $first_process tem $first_conns conexoes ativas" >> "$LOG_FILE"
        # Tenta mostrar notificacao
        show_notification "Alerta de Rede" "Processo $first_process esta usando muitas conexoes! ($first_conns conexoes)"
    fi
else
    echo "Nenhum processo com consumo significativo de rede encontrado."
    echo "$DATA_HORA | Nenhum processo com consumo significativo de rede encontrado" >> "$LOG_FILE"
fi

echo "" >> "$LOG_FILE"

echo ""
echo "Monitoramento concluido em: $(date '+%d/%m/%Y %H:%M:%S')"
echo "Log salvo em: $LOG_FILE"
echo ""
echo -e "\033[1;33mObservações:\033[0m"
echo "- A banda e estimada baseada no numero de conexoes ativas"
echo "- Cada conexao ativa conta como aproximadamente 0.1 Mbps"
echo "- Para monitoramento em tempo real, execute o script periodicamente"
echo ""
echo "Pressione ENTER para sair..."
read