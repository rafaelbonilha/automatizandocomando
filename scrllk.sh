#
# Script em Bash para pressionar a tecla Scroll Lock a cada 4 minutos
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x scrllk.sh
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
# 3-) Como usar.:
#
# Uso Basico.:
# ./scrllk.sh
#
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab#
#
#!/bin/bash

clear
echo -e "\033[31mTeste de pressionamento do botão Scroll Lock.\033[0m"

while true
do
    # Primeiro pressionamento (liga Scroll Lock)
    xdotool key Scroll_Lock
    sleep 0.1
    
    # Segundo pressionamento (desliga Scroll Lock)
    xdotool key Scroll_Lock
    sleep 240
done
