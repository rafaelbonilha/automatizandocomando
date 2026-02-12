#
# Script em Bash para pressionar a tecla Scroll Lock a cada 4 minutos
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x prtsc.sh
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
# ./prtsc.sh
#
# Para o Linux que usa o Wayland.: 
# sudo apt install gnome-screenshot
# ./prtsc.sh 
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab#
#
#!/bin/bash

INTERVALO=20  # segundos
CONTADOR=1

# Verifica se foi fornecido um argumento para intervalo
if [ ! -z "$1" ]; then
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        INTERVALO=$1
    else
        echo "Erro: O intervalo deve ser um número inteiro positivo."
        echo "Uso: ./autoprtsc.sh [intervalo_em_segundos]"
        exit 1
    fi
fi

# Funcao para simular a tecla Print Screen
simular_print_screen() {
    # Tenta usar xdotool (recomendado para ambientes X11)
    if command -v xdotool &> /dev/null; then
        xdotool key Print
        echo "[$CONTADOR] Print Screen capturado em: $(date '+%H:%M:%S')"
    
    # Alternativa para Wayland usando gnome-screenshot
    elif command -v gnome-screenshot &> /dev/null; then
        gnome-screenshot -c
        echo "[$CONTADOR] Print Screen capturado em: $(date '+%H:%M:%S')"
    
    # Alternativa usando import do ImageMagick
    elif command -v import &> /dev/null; then
        import -window root "screenshot_$(date '+%Y%m%d_%H%M%S').png"
        echo "[$CONTADOR] Print Screen capturado em: $(date '+%H:%M:%S') - Salvo como PNG"
    
    # Alternativa para macOS
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        screencapture -x ~/Desktop/screenshot_$(date '+%Y%m%d_%H%M%S').png
        echo "[$CONTADOR] Print Screen capturado em: $(date '+%H:%M:%S') - Salvo na área de trabalho"
    
    else
        echo "Erro: Nenhum programa compatível encontrado para captura de tela."
        echo "Instale xdotool, gnome-screenshot, ImageMagick ou (para macOS) use o script nativo."
        exit 1
    fi
    
    ((CONTADOR++))
}

# Funcao para limpeza ao sair
cleanup() {
    echo ""
    echo "Script finalizado. Total de capturas: $((CONTADOR-1))"
    exit 0
}

# Captura sinais de interrupcao
trap cleanup SIGINT SIGTERM

# Loop principal
while true; do
    simular_print_screen
    sleep $INTERVALO
done
