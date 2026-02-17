#
# Script em Bash para verificar o consumo em disco do computador e avisar o usuario em caso de ultrapassar 75%
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x hdwarning.sh
# 2-) Instale as dependencias para notificacao grafica.:
# 
#  Debian.:
#  sudo apt install zenity
#
# 3-) Para envio de notificacoes.:
#
#  Debian.: 
#  sudo apt install libnotify-bin
#
#  RHEL/CentOS/Fedora.:
#  sudo yum/dnf install libnotify-bin
#
#  Arch.:
#  sudo pacman -S libnotify-bin
#
#
# 3-) Como usar.:
#
# Uso Basico.:
# ./hdwarning.sh 
#
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab#
#
#
#!/bin/bash

# Caminho do arquivo de log
logPath="/caminho/para/seu/projeto/HistoricoDisco.txt"

# Captura data/hora da execucao
dataHora=$(date '+%d/%m/%Y %H:%M:%S')

# Obtem informacoes dos discos (sistemas de arquivos montados)
# Filtra apenas sistemas de arquivos comuns (ext4, xfs, etc) e ignora tmpfs, devtmpfs
df -h | grep -E '^/dev/' | while read linha; do
    # Extrai as informações do df
    filesystem=$(echo $linha | awk '{print $1}')
    tamanho=$(echo $linha | awk '{print $2}')
    usado=$(echo $linha | awk '{print $3}')
    disponivel=$(echo $linha | awk '{print $4}')
    uso_percent=$(echo $linha | awk '{print $5}' | sed 's/%//')
    ponto_montagem=$(echo $linha | awk '{print $6}')
    
    # Converte o percentual de uso para numero
    uso_percent_num=$uso_percent
    
    # Texto para log
    linhaLog="$dataHora | Disco $ponto_montagem | Total: $tamanho | Usado: $usado | Livre: $disponivel | Uso: $uso_percent%"
    
    # Grava o historico no arquivo txt
    echo "$linhaLog" >> "$logPath"
    
    # Exibe alerta se o consumo de disco for acima de 75%
    if [ $uso_percent_num -gt 75 ]; then
        echo "ALERTA: Disco $ponto_montagem esta com $uso_percent% de uso!"
        # No Linux, podemos usar zenity, kdialog ou notify-send para alertas graficos
        if command -v zenity &> /dev/null; then
            zenity --warning --text="ALERTA: Disco $ponto_montagem esta com $uso_percent% de uso!" --title="Consumo de Disco"
        elif command -v notify-send &> /dev/null; then
            notify-send -u critical "Consumo de Disco" "ALERTA: Disco $ponto_montagem esta com $uso_percent% de uso!"
        else
            echo "ALERTA: Disco $ponto_montagem esta com $uso_percent% de uso!" >&2
        fi
    else
        echo -e "\033[0;32mDisco $ponto_montagem esta saudavel ($uso_percent% de uso).\033[0m"
    fi
done