#
# Script em Bash que remove as branches de acordo com a necessidade e registra a atividade em log
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x cls_branches.sh
#
# 2-) Como usar.:
#
# Uso Basico.:
# ./cls_branches.sh
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab
#
#!/bin/bash

# Caminho do arquivo de log
LOG_FILE="./cleanup-branches.log"

# Funcao para escrever no log
write_log() {
    local message="$1"
    local timestamp

    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local log_message="[$timestamp] $message"

    # Exibe no console
    echo "$log_message"

    # Salva no arquivo
    echo "$log_message" >> "$LOG_FILE"
}

write_log "Iniciando limpeza de branches locais..."

# Pegar o nome da branch atual
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

write_log "Branch atual: $CURRENT_BRANCH"

# Branches que deverão ser mantidas
BRANCHES_TO_KEEP=("main" "master" "develop" "$CURRENT_BRANCH")

write_log "Branches protegidas: ${BRANCHES_TO_KEEP[*]}"

# Listar todas as branches locais
git branch --format='%(refname:short)' | while read -r branch; do

    KEEP=false

    # Verifica se a branch deve ser mantida
    for protected in "${BRANCHES_TO_KEEP[@]}"; do
        if [[ "$branch" == "$protected" ]]; then
            KEEP=true
            break
        fi
    done

    # Remove a branch caso nao esteja protegida
    if [[ "$KEEP" == false ]]; then
        if git branch -D "$branch" >/dev/null 2>&1; then
            write_log "Branch '$branch' removida com sucesso!"
        else
            write_log "Erro ao remover branch '$branch'"
        fi
    fi
done

write_log "Limpeza finalizada."