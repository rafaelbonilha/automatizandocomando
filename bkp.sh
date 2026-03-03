#
# Script em Bash que irá fazer backup de arquivos de um diretório para outro e salva a atividade em arquivo txt
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x bkp.sh
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
# ./bkp.sh
#
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab
#
#!/bin/bash

# Configuracoes 
origem="$HOME/PastaAFazeroBKP"
destino="EnderecoDeDestinoDoBKP"
nomeBackup="PastaBkp"  # Pode colocar o nome que achar melhor
logDir="DiretorioOndeFicaraOsLogs/HistoricoBkp"
logFile="$logDir/Backup_$(date +'%Y-%m-%d').log"
dataHoraFormatada=$(date +'%d/%m/%Y %H:%M:%S')

# Criar diretorio de log caso precise
mkdir -p "$logDir"

# Funcoes
function write_log {
    local message="$1"
    local status="${2:-INFO}"
    local timestamp=$(date +'%d/%m/%Y %H:%M:%S')
    local logMessage="$timestamp | $status | $message"
    echo "$logMessage" >> "$logFile"
}

function get_folder_size {
    local folderPath="$1"
    if [ -d "$folderPath" ]; then
        du -sb "$folderPath" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}

function format_file_size {
    local bytes=$1
    
    if [ $bytes -gt 1099511627776 ]; then  # 1TB em bytes
        echo "$(echo "scale=2; $bytes / 1099511627776" | bc) TB"
    elif [ $bytes -gt 1073741824 ]; then   # 1GB em bytes
        echo "$(echo "scale=2; $bytes / 1073741824" | bc) GB"
    elif [ $bytes -gt 1048576 ]; then       # 1MB em bytes
        echo "$(echo "scale=2; $bytes / 1048576" | bc) MB"
    elif [ $bytes -gt 1024 ]; then          # 1KB em bytes
        echo "$(echo "scale=2; $bytes / 1024" | bc) KB"
    else
        echo "${bytes} B"
    fi
}

# Limpa a tela
clear

echo -e "\033[36m=========================================\033[0m"
echo -e "\033[36m        INICIANDO PROCESSO DE BACKUP      \033[0m"
echo -e "\033[36m=========================================\033[0m"
echo ""

write_log "=== INICIO DO BACKUP: $nomeBackup ==="
write_log "Origem: $origem"
write_log "Destino: $destino"

# Verifica se a origem existe
if [ ! -d "$origem" ]; then
    erroMsg="ERRO: Pasta de origem nao encontrada: $origem"
    echo -e "\033[31m$erroMsg\033[0m"
    write_log "$erroMsg" "ERRO"
    exit 1
fi

# Verifica se tem espaço em disco no destino 
destinoDrive=$(echo "$destino" | cut -d'/' -f2)
if [ -n "$destinoDrive" ] && [ -d "/$destinoDrive" ]; then
    freeSpace=$(df -B1 "/$destinoDrive" | tail -1 | awk '{print $4}')
    freeSpaceFormatado=$(format_file_size $freeSpace)
    echo -e "\033[33mEspaco livre no destino: $freeSpaceFormatado\033[0m"
    write_log "Espaco livre no destino: $freeSpaceFormatado"
fi

# Calcula tamanho da origem
echo -e "\033[33mCalculando tamanho da origem...\033[0m"
tamanhoOrigemBytes=$(get_folder_size "$origem")
tamanhoOrigem=$(echo "scale=2; $tamanhoOrigemBytes / 1048576" | bc)  # Em MB
tamanhoOrigemFormatado=$(format_file_size $tamanhoOrigemBytes)
echo -e "\033[33mTamanho da origem: $tamanhoOrigemFormatado\033[0m"
write_log "Tamanho da origem: $tamanhoOrigemFormatado"

# Cria nome da pasta com data/hora para bkp
dataHoraArquivo=$(date +'%Y-%m-%d_%H%M%S')
destinoComData="$destino/${nomeBackup}_${dataHoraArquivo}"

echo ""
echo -e "\033[32mCopiando arquivos...\033[0m"
write_log "Iniciando copia dos arquivos..."

start_time=$(date +%s)

# Realiza o backup
if cp -r "$origem" "$destinoComData" 2>/dev/null; then
    # Calcula tempo total
    end_time=$(date +%s)
    tempoTotal=$((end_time - start_time))
    tempoFormatado=$(printf '%02d:%02d:%02d' $((tempoTotal/3600)) $((tempoTotal%3600/60)) $((tempoTotal%60)))
    
    # Verifica se o backup foi criado
    if [ -d "$destinoComData" ]; then
        # Calcula tamanho do backup
        tamanhoBackupBytes=$(get_folder_size "$destinoComData")
        tamanhoBackup=$(echo "scale=2; $tamanhoBackupBytes / 1048576" | bc)
        tamanhoBackupFormatado=$(format_file_size $tamanhoBackupBytes)
        
        # Conta numero de arquivos e pastas
        numArquivos=$(find "$destinoComData" -type f 2>/dev/null | wc -l)
        numPastas=$(find "$destinoComData" -type d 2>/dev/null | wc -l)
        numPastas=$((numPastas - 1))  # Remove a contagem da pasta raiz
        
        echo ""
        echo -e "\033[32m=========================================\033[0m"
        echo -e "\033[32m        BACKUP CONCLUIDO COM SUCESSO      \033[0m"
        echo -e "\033[32m=========================================\033[0m"
        echo ""
        echo -e "\033[37mResumo do Backup:\033[0m"
        echo -e "\033[90m   Origem: $origem\033[0m"
        echo -e "\033[90m   Destino: $destinoComData\033[0m"
        echo -e "\033[90m   Arquivos copiados: $numArquivos\033[0m"
        echo -e "\033[90m   Pastas criadas: $numPastas\033[0m"
        echo -e "\033[90m   Tamanho do backup: $tamanhoBackupFormatado\033[0m"
        echo -e "\033[90m   Tempo total: $tempoFormatado\033[0m"
        echo ""
        
        # Log detalhado
        write_log "=== BACKUP CONCLUIDO COM SUCESSO ==="
        write_log "Destino final: $destinoComData"
        write_log "Arquivos copiados: $numArquivos"
        write_log "Pastas criadas: $numPastas"
        write_log "Tamanho do backup: $tamanhoBackupFormatado"
        write_log "Tempo total: $tempoFormatado"
        
        # Notificacao (usando notify-send)
        if command -v notify-send &> /dev/null; then
            notify-send "✅ Backup Concluido" \
                       "Backup de '$nomeBackup' concluido!\nArquivos: $numArquivos | Tamanho: $tamanhoBackupFormatado\nTempo: $tempoFormatado" \
                       -t 10000
        fi
        
        # Abre a pasta de bkp (opcional)
        read -p "Deseja abrir a pasta de destino? (S/N) " resposta
        if [[ "$resposta" =~ ^[Ss]$ ]]; then
            xdg-open "$destinoComData" 2>/dev/null || open "$destinoComData" 2>/dev/null || echo "Nao foi possivel abrir a pasta"
        fi
    fi
else
    erroMsg="ERRO durante o backup"
    echo ""
    echo -e "\033[31m$erroMsg\033[0m"
    
    write_log "$erroMsg" "ERRO"
fi

write_log "=== FIM DO BACKUP ==="
write_log ""

echo ""
echo -e "\033[32mLog do backup salvo em: $logFile\033[0m"
echo ""

# Mostra ultimas linhas do log (opcional)
read -p "Deseja ver o log do backup? (S/N) " verLog
if [[ "$verLog" =~ ^[Ss]$ ]] && [ -f "$logFile" ]; then
    echo ""
    echo -e "\033[33mUltimas 10 linhas do log:\033[0m"
    tail -10 "$logFile"
fi

echo ""
echo -e "\033[90mPressione ENTER para sair...\033[0m"
read