#
# Script em Bash que muda o diretorio automaticamente
#
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x autostart.sh
#
#
# 2-) Como usar.:
#
# Uso Basico.:
# ./autostart.sh
#
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab
#
#!/bin/bash

PATH_AUTOSTART="$HOME/.config/autostart"

{
    if [ ! -d "$PATH_AUTOSTART" ]; then
        echo "Pasta de inicio automatico nao existe no caminho.: $PATH_AUTOSTART"
        exit 1
    fi

    cd "$PATH_AUTOSTART" || exit 1
    echo "$PATH_AUTOSTART"
    exit 0

} || {
    echo "Erro: nao foi possivel acessar o diretorio $PATH_AUTOSTART"
    exit 1
}