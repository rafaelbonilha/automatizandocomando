#
# Script em Bash para validar o consumo de memoria RAM e emite alerta se o consumo estiver acima de 75%.
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x memattencion.sh
# 2-) Instale as dependencias.: 
#  Debian.:
#  sudo apt install bc
#
#  RHEL/CentOS/Fedora.:
#  sudo yum/dnf install bc
#
#
# 3-) Como usar.:
#
# Uso Basico.:
# ./memattencion.sh
#
# Para o Linux que usa o Wayland.: 
# sudo apt install gnome-screenshot
# ./memattencion.sh 
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab#
#
#!/bin/bash

# Caminho do arquivo de log
LOG_PATH="/caminho/para/seu/log/HistoricoMemoria.txt"

# Verifica se o diretorio do log existe, se nao, cria
LOG_DIR=$(dirname "$LOG_PATH")
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi

# Captura data/hora da execucao
DATA_HORA=$(date '+%d/%m/%Y %H:%M:%S')

# Obtem informacoes de memória do sistema
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
FREE_MEM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')

# Se MemAvailable nao estiver disponivel, calcula de outra forma
if [ -z "$FREE_MEM_KB" ]; then
    FREE_MEM_KB=$(grep MemFree /proc/meminfo | awk '{print $2}')
fi

# Converte para GB (1 GB = 1048576 KB)
TOTAL_GB=$(echo "scale=2; $TOTAL_MEM_KB / 1048576" | bc)
FREE_GB=$(echo "scale=2; $FREE_MEM_KB / 1048576" | bc)
USED_GB=$(echo "scale=2; $TOTAL_GB - $FREE_GB" | bc)

# Calcula porcentagem de uso
USO=$(echo "scale=2; ($TOTAL_MEM_KB - $FREE_MEM_KB) * 100 / $TOTAL_MEM_KB" | bc)
USO_FORMATADO=$(echo "$USO" | awk '{printf "%.2f", $0}')

# Texto para log
LINHA_LOG="$DATA_HORA | Memoria RAM | Total: ${TOTAL_GB}GB | Usado: ${USED_GB}GB | Livre: ${FREE_GB}GB | Uso: ${USO_FORMATADO}%"

# Grava o historico no arquivo txt
echo "$LINHA_LOG" >> "$LOG_PATH"

# Funcao para exibir mensagens coloridas no terminal
show_colored() {
    case $2 in
        "red")    echo -e "\033[0;31m$1\033[0m" ;;
        "green")  echo -e "\033[0;32m$1\033[0m" ;;
        "yellow") echo -e "\033[1;33m$1\033[0m" ;;
        "cyan")   echo -e "\033[0;36m$1\033[0m" ;;
        *)        echo "$1" ;;
    esac
}

# Funcao para mostrar alerta grafico (usando notify-send no Linux)
show_graphic_alert() {
    if command -v notify-send &> /dev/null; then
        notify-send -u critical -t 10000 \
            "Consumo de Memória RAM" \
            "ALERTA: Memória RAM está com ${USO_FORMATADO}% de uso!\nTotal: ${TOTAL_GB}GB | Usado: ${USED_GB}GB | Livre: ${FREE_GB}GB"
    else
        # Se notify-send nao estiver disponivel, usa o terminal
        echo "==========================================="
        show_colored "ALERTA CRÍTICO!" "red"
        show_colored "Memória RAM está com ${USO_FORMATADO}% de uso!" "red"
        echo "Total: ${TOTAL_GB}GB | Usado: ${USED_GB}GB | Livre: ${FREE_GB}GB"
        echo "==========================================="
    fi
}

# Exibe alerta se o consumo de memoria for acima de 75%
if (( $(echo "$USO > 75" | bc -l) )); then
    # Mostra alerta gráfico
    show_graphic_alert
    
    # Exibe no console em vermelho
    echo ""
    show_colored "ALERTA: Memória RAM está com ${USO_FORMATADO}% de uso!" "red"
    show_colored "Total: ${TOTAL_GB}GB | Usado: ${USED_GB}GB | Livre: ${FREE_GB}GB" "yellow"
else
    echo ""
    show_colored "Memória RAM está saudável (${USO_FORMATADO}% de uso)." "green"
    show_colored "Total: ${TOTAL_GB}GB | Usado: ${USED_GB}GB | Livre: ${FREE_GB}GB" "cyan"
fi

# Exibe local do log
echo ""
echo "Log salvo em: $LOG_PATH"