#
# Script em Bash para reiniciar o computador e avisar o usuario
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x reinicia.sh
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
# ./reinicia.sh tempo em segundos
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


# Configuracoes
TEMPO_ESPERA=${1:-60}  # segundos (padrao: 60 se nao informado)
MENSAGEM="ATENCAO: O computador sera reiniciado em $TEMPO_ESPERA segundos. Salve seu trabalho!"

# Verifica se esta rodando como root (necessario para reinicializacao)
if [ "$EUID" -ne 0 ]; then 
    echo "Por favor, execute como root (use sudo)"
    exit 1
fi

# Verifica o sistema operacional
OS_TYPE="unknown"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
else
    echo "Sistema operacional nao suportado: $OSTYPE"
    exit 1
fi

# Funcao para mostrar mensagem em pop-up
show_popup_linux() {
    local message="$1"
    local title="$2"
    local timeout="$3"
    
    # Tenta diferentes metodos para mostrar pop-up
    if command -v zenity &> /dev/null; then
        zenity --info --title="$title" --text="$message" --timeout="$timeout" 2>/dev/null &
    elif command -v kdialog &> /dev/null; then
        kdialog --title "$title" --passivepopup "$message" "$timeout" &
    elif command -v notify-send &> /dev/null; then
        notify-send -u critical -t "$((timeout * 1000))" "$title" "$message" &
    elif command -v xmessage &> /dev/null; then
        echo "$message" | xmessage -timeout "$timeout" -center -file - &
    else
        # Fallback para o terminal
        echo "[POP-UP] $title: $message"
    fi
}

# Funcao para mostrar mensagem em pop-up (macOS)
show_popup_macos() {
    local message="$1"
    local title="$2"
    local timeout="$3"
    
    osascript -e "display dialog \"$message\" with title \"$title\" buttons {\"OK\"} default button \"OK\" giving up after $timeout" 2>/dev/null &
}

# Funcao para mostrar mensagem para todos os usuarios
show_message_all_users() {
    local message="$1"
    local is_critical="$2"
    
    # Mostra no console atual
    if [ "$is_critical" = "critical" ]; then
        echo -e "\e[31m$message\e[0m"  # Vermelho
    else
        echo -e "\e[33m$message\e[0m"  # Amarelo
    fi
    
    # Tenta enviar para todos os terminais (Linux)
    if [ "$OS_TYPE" = "linux" ]; then
        # Envia para todos os usuários via wall
        echo "$message" | wall 2>/dev/null
        
        # Tenta enviar para terminais especificos
        for terminal in /dev/pts/*; do
            if [ -w "$terminal" ]; then
                if [ "$is_critical" = "critical" ]; then
                    echo -e "\033[31m$message\033[0m" > "$terminal" 2>/dev/null
                else
                    echo -e "\033[33m$message\033[0m" > "$terminal" 2>/dev/null
                fi
            fi
        done
    fi
    
    # Mostra pop-up baseado no SO
    if [ "$OS_TYPE" = "linux" ]; then
        show_popup_linux "$message" "AVISO DE REINICIALIZAÇÃO" 10
    elif [ "$OS_TYPE" = "macos" ]; then
        show_popup_macos "$message" "AVISO DE REINICIALIZAÇÃO" 10
    fi
}

# Funcao para reiniciar o sistema
reboot_system() {
    echo -e "\e[31mREINICIANDO O COMPUTADOR...\e[0m"
    
    # Pop-up final
    if [ "$OS_TYPE" = "linux" ]; then
        show_popup_linux "REINICIANDO AGORA!" "REINICIALIZAÇÃO" 2
    elif [ "$OS_TYPE" = "macos" ]; then
        show_popup_macos "REINICIANDO AGORA!" "REINICIALIZAÇÃO" 2
    fi
    
    sleep 2
    
    # Comando de reinicializacao especifico por SO
    case $OS_TYPE in
        linux)
            if command -v systemctl &> /dev/null; then
                systemctl reboot
            else
                reboot
            fi
            ;;
        macos)
            shutdown -r now
            ;;
    esac
}

clear
echo "========================================="
echo "  AVISO DE REINICIALIZAÇÃO DO SISTEMA"
echo "========================================="
echo "Tempo até reinicialização: $TEMPO_ESPERA segundos"
echo "Pressione CTRL+C para cancelar"
echo "========================================="
echo ""

# Mensagem inicial
show_message_all_users "$MENSAGEM"

# Contagem regressiva (a cada 10 segundos)
for ((i=TEMPO_ESPERA; i>10; i-=10)); do
    sleep 10
    
    msg_restante="Reinicialização em $i segundos..."
    if [ $i -le 30 ]; then
        show_message_all_users "$msg_restante"
    else
        echo -e "\e[33m$msg_restante\e[0m"
    fi
done

# Ultimos 10 segundos (contagem regressiva de 1 em 1)
for ((i=10; i>0; i--)); do
    msg_final="Reinicialização em $i segundos..."
    
    if [ $i -le 5 ]; then
        show_message_all_users "$msg_final" "critical"
    else
        echo -e "\e[31m$msg_final\e[0m"
    fi
    
    sleep 1
done

# Mensagem final e reinicializacao
show_message_all_users "REINICIANDO AGORA!" "critical"
reboot_system