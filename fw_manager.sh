#
# Script em Bash que gerencia o fw e salva a atividade em um arquivo txt
#
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x fw_manager.sh
#
# 2-) Instale as dependencias, caso deseje enviar notificacao
#  Debian.:
#  sudo apt install  notify-send
#
#  RHEL/CentOS/Fedora.:
#  sudo dnf install notify-send ou
#  sudo yum install notify-send (CentOS)
# 
# Instale o iptables-persistent para não perder as regras do iptables em caso de reinicializacao
# sudo apt install iptables-persistent
# Para sistemas CentOS/RHEL.:
# sudo yum install iptables-persistent
#
# 3-) Como usar.:
#
# Uso Basico.:
# ./fw_manager.sh
#
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab
#
#!/bin/bash

# Verifica se esta rodando como root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}ERRO: Este script precisa ser executado como root!${NC}"
    echo "Execute: sudo ./fw_manager.sh"
    exit 1
fi
 
# -----------------------------------------------------------
# CONFIGURACOES
# -----------------------------------------------------------
LOG_DIR="$HOME/GestaoFirewall"
LOG_FILE="$LOG_DIR/Firewall_$(date '+%Y-%m-%d').log"
REPORT_FILE="$LOG_DIR/Relatorio_$(date '+%Y-%m-%d_%H-%M-%S').txt"
BACKUP_FILE="$LOG_DIR/Backup_$(date '+%Y-%m-%d_%H-%M-%S').rules"
 
mkdir -p "$LOG_DIR"
 
# -----------------------------------------------------------
# CORES
# -----------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'
 
# -----------------------------------------------------------
# FUNCOES UTILITARIAS
# -----------------------------------------------------------
 
write_log() {
    local message="$1"
    local status="${2:-INFO}"
    local timestamp
    timestamp=$(date '+%d/%m/%Y %H:%M:%S')
    local log_message="$timestamp | $status | $message"
 
    echo "$log_message" >> "$LOG_FILE"
 
    case "$status" in
        ERRO)    echo -e "${RED}${log_message}${NC}" ;;
        SUCESSO) echo -e "${GREEN}${log_message}${NC}" ;;
        AVISO)   echo -e "${YELLOW}${log_message}${NC}" ;;
        *)       echo -e "${GRAY}${log_message}${NC}" ;;
    esac
}
 
write_section() {
    local title="$1"
    local line
    line=$(printf '=%.0s' {1..60})
    echo ""
    echo -e "${CYAN}${line}${NC}"
    echo -e "${CYAN}  ${title}${NC}"
    echo -e "${CYAN}${line}${NC}"
}
 
add_to_report() {
    echo "$1" >> "$REPORT_FILE"
}
 
press_any_key() {
    echo ""
    echo -e "${GRAY}Pressione ENTER para continuar...${NC}"
    read -r
}
 
# -----------------------------------------------------------
# FUNCOES DE FIREWALL
# -----------------------------------------------------------
 
get_regras_firewall() {
    write_section "REGRAS DE FIREWALL ATIVAS"
    write_log "Listando regras de firewall" "INFO"
 
    echo ""
    read -rp "Filtrar por direcao? (I=Entrada/INPUT / O=Saida/OUTPUT / T=Todas): " direcao
 
    echo ""
    case "${direcao^^}" in
        I)
            echo -e "${YELLOW}  Regras de ENTRADA (INPUT):${NC}"
            iptables -L INPUT -n -v --line-numbers 2>/dev/null
            ;;
        O)
            echo -e "${YELLOW}  Regras de SAIDA (OUTPUT):${NC}"
            iptables -L OUTPUT -n -v --line-numbers 2>/dev/null
            ;;
        *)
            echo -e "${YELLOW}  Todas as regras:${NC}"
            iptables -L -n -v --line-numbers 2>/dev/null
            ;;
    esac
 
    local total
    total=$(iptables -L -n 2>/dev/null | grep -c '^[0-9]')
    echo ""
    echo -e "${CYAN}  Total de regras encontradas: $total${NC}"
    write_log "Listadas $total regras" "INFO"
}
 
add_regra_entrada() {
    write_section "ADICIONAR REGRA DE ENTRADA (INPUT)"
    write_log "Iniciando adicao de regra de entrada" "INFO"
 
    echo ""
    read -rp "  Protocolo (tcp / udp / all) [tcp]: " protocolo
    protocolo="${protocolo:-tcp}"
 
    read -rp "  Porta(s) de destino (ex: 80 ou 8080:8090, deixe vazio para qualquer): " porta
    read -rp "  Acao (ACCEPT / DROP / REJECT) [ACCEPT]: " acao
    acao="${acao:-ACCEPT}"
    read -rp "  IP de origem (deixe vazio para qualquer): " ip_origem
    read -rp "  Comentario/descricao da regra (opcional): " comentario
 
    # Monta o comando
    local cmd="iptables -A INPUT -p $protocolo"
    [ -n "$porta" ]     && cmd="$cmd --dport $porta"
    [ -n "$ip_origem" ] && cmd="$cmd -s $ip_origem"
    [ -n "$comentario" ] && cmd="$cmd -m comment --comment \"$comentario\""
    cmd="$cmd -j $acao"
 
    echo ""
    echo -e "${YELLOW}  Comando a executar:${NC} $cmd"
    read -rp "  Confirmar? (S/N): " confirm
 
    if [[ "${confirm^^}" != "S" ]]; then
        write_log "Adicao de regra de entrada cancelada" "AVISO"
        return
    fi
 
    if eval "$cmd" 2>/dev/null; then
        write_log "Regra de entrada adicionada: protocolo=$protocolo porta=$porta acao=$acao origem=${ip_origem:-any}" "SUCESSO"
        echo -e "${GREEN}  Regra adicionada com sucesso!${NC}"
    else
        write_log "Erro ao adicionar regra de entrada" "ERRO"
        echo -e "${RED}  Erro ao adicionar regra.${NC}"
    fi
}
 
add_regra_saida() {
    write_section "ADICIONAR REGRA DE SAIDA (OUTPUT)"
    write_log "Iniciando adicao de regra de saida" "INFO"
 
    echo ""
    read -rp "  Protocolo (tcp / udp / all) [tcp]: " protocolo
    protocolo="${protocolo:-tcp}"
 
    read -rp "  Porta(s) de destino (ex: 443 ou 8080:8090, deixe vazio para qualquer): " porta
    read -rp "  Acao (ACCEPT / DROP / REJECT) [ACCEPT]: " acao
    acao="${acao:-ACCEPT}"
    read -rp "  IP de destino (deixe vazio para qualquer): " ip_destino
    read -rp "  Comentario/descricao da regra (opcional): " comentario
 
    local cmd="iptables -A OUTPUT -p $protocolo"
    [ -n "$porta" ]      && cmd="$cmd --dport $porta"
    [ -n "$ip_destino" ] && cmd="$cmd -d $ip_destino"
    [ -n "$comentario" ] && cmd="$cmd -m comment --comment \"$comentario\""
    cmd="$cmd -j $acao"
 
    echo ""
    echo -e "${YELLOW}  Comando a executar:${NC} $cmd"
    read -rp "  Confirmar? (S/N): " confirm
 
    if [[ "${confirm^^}" != "S" ]]; then
        write_log "Adicao de regra de saida cancelada" "AVISO"
        return
    fi
 
    if eval "$cmd" 2>/dev/null; then
        write_log "Regra de saida adicionada: protocolo=$protocolo porta=$porta acao=$acao destino=${ip_destino:-any}" "SUCESSO"
        echo -e "${GREEN}  Regra adicionada com sucesso!${NC}"
    else
        write_log "Erro ao adicionar regra de saida" "ERRO"
        echo -e "${RED}  Erro ao adicionar regra.${NC}"
    fi
}
 
remove_regra_firewall() {
    write_section "REMOVER REGRA DE FIREWALL"
    write_log "Iniciando remocao de regra" "INFO"
 
    echo ""
    read -rp "  Chain (INPUT / OUTPUT / FORWARD) [INPUT]: " chain
    chain="${chain:-INPUT}"
 
    echo ""
    echo -e "${YELLOW}  Regras atuais em $chain:${NC}"
    iptables -L "$chain" -n -v --line-numbers 2>/dev/null
 
    echo ""
    read -rp "  Numero da regra a remover: " num
 
    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}  Numero invalido.${NC}"
        write_log "Remocao cancelada: numero invalido '$num'" "AVISO"
        return
    fi
 
    read -rp "  Confirmar remocao da regra $num da chain $chain? (S/N): " confirm
    if [[ "${confirm^^}" != "S" ]]; then
        write_log "Remocao cancelada pelo usuario" "AVISO"
        return
    fi
 
    if iptables -D "$chain" "$num" 2>/dev/null; then
        write_log "Regra $num da chain $chain removida com sucesso" "SUCESSO"
        echo -e "${GREEN}  Regra removida com sucesso!${NC}"
    else
        write_log "Erro ao remover regra $num da chain $chain" "ERRO"
        echo -e "${RED}  Erro ao remover regra.${NC}"
    fi
}
 
set_status_regra() {
    write_section "HABILITAR / DESABILITAR REGRA"
    write_log "Alterando status de regra" "INFO"
 
    echo ""
    echo -e "${YELLOW}  No iptables nao existe habilitar/desabilitar diretamente.${NC}"
    echo -e "${WHITE}  As opcoes equivalentes sao:${NC}"
    echo -e "${WHITE}  1. Inserir nova regra no inicio da chain (prioridade maxima)${NC}"
    echo -e "${WHITE}  2. Remover uma regra existente${NC}"
    echo ""
    read -rp "  Deseja (I)nserir regra no topo ou (R)emover regra existente? " opcao
 
    case "${opcao^^}" in
        I)
            read -rp "  Chain (INPUT / OUTPUT / FORWARD) [INPUT]: " chain
            chain="${chain:-INPUT}"
            read -rp "  Protocolo (tcp / udp / all) [tcp]: " protocolo
            protocolo="${protocolo:-tcp}"
            read -rp "  Porta: " porta
            read -rp "  Acao (ACCEPT / DROP) [ACCEPT]: " acao
            acao="${acao:-ACCEPT}"
 
            local cmd="iptables -I $chain 1 -p $protocolo"
            [ -n "$porta" ] && cmd="$cmd --dport $porta"
            cmd="$cmd -j $acao"
 
            if eval "$cmd" 2>/dev/null; then
                write_log "Regra inserida no topo de $chain: protocolo=$protocolo porta=$porta acao=$acao" "SUCESSO"
                echo -e "${GREEN}  Regra inserida com sucesso!${NC}"
            else
                write_log "Erro ao inserir regra no topo de $chain" "ERRO"
                echo -e "${RED}  Erro ao inserir regra.${NC}"
            fi
            ;;
        R)
            remove_regra_firewall
            ;;
        *)
            echo -e "${YELLOW}  Opcao invalida.${NC}"
            ;;
    esac
}
 
get_detalhes_regra() {
    write_section "DETALHES DAS REGRAS"
    write_log "Consultando detalhes de regra" "INFO"
 
    echo ""
    read -rp "  Chain (INPUT / OUTPUT / FORWARD / all) [all]: " chain
    chain="${chain:-all}"
 
    echo ""
    if [[ "${chain^^}" == "ALL" ]]; then
        iptables -L -n -v --line-numbers 2>/dev/null
    else
        iptables -L "$chain" -n -v --line-numbers 2>/dev/null
    fi
 
    echo ""
    echo -e "${CYAN}  Politicas padrao:${NC}"
    iptables -L | grep "^Chain" 2>/dev/null
}
 
export_regras_firewall() {
    write_section "EXPORTAR REGRAS PARA TXT"
    write_log "Exportando regras de firewall" "INFO"
 
    {
        echo "RELATORIO DE REGRAS DE FIREWALL"
        echo "Gerado em: $(date '+%d/%m/%Y %H:%M:%S')"
        echo "Servidor : $(hostname)"
        printf '=%.0s' {1..60}
        echo ""
        echo ""
        echo "=== REGRAS INPUT ==="
        iptables -L INPUT -n -v --line-numbers 2>/dev/null
        echo ""
        echo "=== REGRAS OUTPUT ==="
        iptables -L OUTPUT -n -v --line-numbers 2>/dev/null
        echo ""
        echo "=== REGRAS FORWARD ==="
        iptables -L FORWARD -n -v --line-numbers 2>/dev/null
        echo ""
        echo "=== FORMATO COMPLETO (iptables-save) ==="
        iptables-save 2>/dev/null
    } > "$REPORT_FILE"
 
    echo -e "${GREEN}  Relatorio salvo em: $REPORT_FILE${NC}"
    write_log "Regras exportadas para $REPORT_FILE" "SUCESSO"
}
 
backup_regras_firewall() {
    write_section "BACKUP DAS REGRAS DE FIREWALL"
    write_log "Realizando backup das regras" "INFO"
 
    if iptables-save > "$BACKUP_FILE" 2>/dev/null; then
        echo -e "${GREEN}  Backup salvo em: $BACKUP_FILE${NC}"
        write_log "Backup realizado com sucesso em $BACKUP_FILE" "SUCESSO"
    else
        write_log "Erro ao realizar backup" "ERRO"
        echo -e "${RED}  Erro ao realizar backup.${NC}"
    fi
}
 
restore_regras_firewall() {
    write_section "RESTAURAR REGRAS DE FIREWALL"
    write_log "Iniciando restauracao de regras" "INFO"
 
    local backups
    backups=$(find "$LOG_DIR" -name "*.rules" 2>/dev/null | sort -r | head -5)
 
    if [ -z "$backups" ]; then
        echo -e "${YELLOW}  Nenhum arquivo de backup (.rules) encontrado em $LOG_DIR${NC}"
        return
    fi
 
    echo ""
    echo -e "${YELLOW}  Backups disponiveis:${NC}"
    echo "$backups" | while read -r arq; do
        echo -e "${WHITE}    $arq${NC}"
    done
 
    echo ""
    read -rp "  Informe o caminho completo do backup a restaurar: " caminho
 
    if [ ! -f "$caminho" ]; then
        echo -e "${RED}  Arquivo nao encontrado: $caminho${NC}"
        return
    fi
 
    read -rp "  ATENCAO: isso substituira as regras atuais. Confirmar? (S/N): " confirm
    if [[ "${confirm^^}" != "S" ]]; then
        write_log "Restauracao cancelada pelo usuario" "AVISO"
        return
    fi
 
    if iptables-restore < "$caminho" 2>/dev/null; then
        write_log "Regras restauradas com sucesso de $caminho" "SUCESSO"
        echo -e "${GREEN}  Regras restauradas com sucesso!${NC}"
    else
        write_log "Erro ao restaurar regras de $caminho" "ERRO"
        echo -e "${RED}  Erro ao restaurar regras.${NC}"
    fi
}
 
# -----------------------------------------------------------
# INICIO
# -----------------------------------------------------------
 
clear
 
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}      GESTAO DE FIREWALL - LINUX         ${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
 
write_log "=== INICIO DA GESTAO DE FIREWALL ==="
 
while true; do
    echo ""
    echo -e "${YELLOW}OPCOES DISPONIVEIS:${NC}"
    echo -e "${WHITE}1.  Listar regras ativas${NC}"
    echo -e "${WHITE}2.  Adicionar regra de entrada (INPUT)${NC}"
    echo -e "${WHITE}3.  Adicionar regra de saida (OUTPUT)${NC}"
    echo -e "${WHITE}4.  Remover regra por numero${NC}"
    echo -e "${WHITE}5.  Habilitar / Desabilitar regra${NC}"
    echo -e "${WHITE}6.  Ver detalhes das regras${NC}"
    echo -e "${WHITE}7.  Exportar todas as regras (txt)${NC}"
    echo -e "${WHITE}8.  Fazer backup das regras (.rules)${NC}"
    echo -e "${WHITE}9.  Restaurar regras de backup${NC}"
    echo -e "${WHITE}0.  Sair${NC}"
 
    echo ""
    read -rp "Escolha uma opcao: " opcao
 
    case "$opcao" in
        1) get_regras_firewall      ;;
        2) add_regra_entrada        ;;
        3) add_regra_saida          ;;
        4) remove_regra_firewall    ;;
        5) set_status_regra         ;;
        6) get_detalhes_regra       ;;
        7) export_regras_firewall   ;;
        8) backup_regras_firewall   ;;
        9) restore_regras_firewall  ;;
        0) break ;;
        *) echo -e "${YELLOW}  Opcao invalida.${NC}" ;;
    esac
 
    if [ "$opcao" != "0" ]; then
        press_any_key
        clear
        echo -e "${CYAN}=========================================${NC}"
        echo -e "${CYAN}      GESTAO DE FIREWALL - LINUX         ${NC}"
        echo -e "${CYAN}=========================================${NC}"
    fi
done
 
write_log "=== FIM DA GESTAO DE FIREWALL ==="
 
echo ""
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}          FERRAMENTA ENCERRADA           ${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
echo -e "${GREEN}Log salvo em: $LOG_FILE${NC}"
echo ""
 
if [ -f "$LOG_FILE" ]; then
    echo -e "${YELLOW}Ultimas operacoes realizadas:${NC}"
    echo ""
    tail -10 "$LOG_FILE" | while read -r linha; do
        if echo "$linha" | grep -q "SUCESSO"; then
            echo -e "${GREEN}$linha${NC}"
        elif echo "$linha" | grep -q "ERRO"; then
            echo -e "${RED}$linha${NC}"
        elif echo "$linha" | grep -q "AVISO"; then
            echo -e "${YELLOW}$linha${NC}"
        else
            echo -e "${GRAY}$linha${NC}"
        fi
    done
fi
 
echo ""
echo -e "${GRAY}Pressione ENTER para sair...${NC}"
read -r