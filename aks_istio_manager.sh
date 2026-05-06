#!/bin/bash
#
#  AKS ISTIO SERVICE MANAGER
#
#  AKS Istio Service Mesh Add-on Manager
#  Autor.: Joao Rafael F. Bonilha baseado no script do Ricardo Lima
#  Data.: 06/05/2026
#  Versao.: 1.0
#  Como usar.: Copiar para a subscricao do cluster aks que deseja gerenciar o
#              istio e adicionar a permissao de execucao via chmod +x
#

set -o pipefail

#
#  CONFIGURACOES GLOBAIS
#
VERSION="3.0.0"
LOG_FILE="/tmp/istio-manager-$(date +%Y%m%d-%H%M%S).log"

# Estado do cluster
RESOURCE_GROUP=""
CLUSTER_NAME=""
LOCATION=""
AKS_VERSION=""
ISTIO_ENABLED=false
CURRENT_REVISION=""
TARGET_REVISION=""
AVAILABLE_UPGRADES=""
NAMESPACES_WITH_ISTIO=()

# Configuracoes de retry
MAX_RETRIES=3
RETRY_DELAY=10

#
#  CORES E FORMATACAO
#
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

#
#  FUNCOES DE UI
#

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

clear_screen() {
    clear
}

show_banner() {
    echo
    echo -e "${CYAN}$(printf '=%.0s' {1..70})${NC}"
    echo -e "${CYAN}${NC}"
    echo -e "  ${BLUE}AKS ISTIO${NC}"
    echo -e "${CYAN}${NC}"
    echo -e "  ${PURPLE}SERVICE${NC}"
    echo -e "${CYAN}${NC}"
    echo -e "  ${WHITE}MESH${NC}"
    echo -e "${CYAN}${NC}"
    echo -e "${CYAN}$(printf '=%.0s' {1..70})${NC}"
    echo -e "  ${GREEN}※${NC} Azure Kubernetes Service - Istio Add-on Intelligent Manager${NC}"
    echo -e "  ${CYAN}v${VERSION}${NC}"
    echo -e "${CYAN}$(printf '=%.0s' {1..70})${NC}"
    echo
}

print_phase() {
    local phase="$1"
    local description="$2"
    echo
    echo -e "${CYAN}$(printf '=%.0s' {1..70})${NC}"
    echo -e "${WHITE}${BOLD}  FASE $phase: $description${NC}"
    echo -e "${CYAN}$(printf '=%.0s' {1..70})${NC}"
    echo ""
    log "FASE $phase: $description"
}

print_step() {
    echo -e "${CYAN} ►${NC} $1"
    log "STEP: $1"
}

print_substep() {
    echo -e "${GRAY} ├${NC} $1"
}

print_success() {
    echo -e "${GREEN} ✓ $1${NC}"
    log "SUCCESS: $1"
}

print_error() {
    echo -e "${RED} ✗ $1${NC}"
    log "ERROR: $1"
}

print_warning() {
    echo -e "${YELLOW} ▲ $1${NC}"
    log "WARNING: $1"
}

print_info() {
    echo -e "${BLUE} ℹ $1${NC}"
    log "INFO: $1"
}

print_action() {
    echo -e "${PURPLE} ◉ $1${NC}"
    log "ACTION: $1"
}

print_wait() {
    echo -e "${GRAY} ⏱ $1${NC}"
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\|/-\'
    while kill -0 $pid 2>/dev/null; do
        for i in $(seq 0 9); do
            printf "\r${CYAN}  %s${NC} Aguarde..." "${spinstr:$i:1}"
            sleep $delay
        done
    done
    printf "\r        \r"
}

confirm() {
    local message="$1"
    echo ""
    read -p "$(echo -e ${YELLOW}" ? $message [S/n]: "${NC})" response
    response=${response:-s}
    [[ "$response" =~ ^[sS]$ ]]
}

#
#  FASE 1: VALIDACAO DO AMBIENTE
#

validate_environment() {
    print_phase "1" "VALIDACAO DO AMBIENTE"

    local errors=0

    # Azure CLI
    print_step "Verificando Azure CLI..."
    if command -v az &> /dev/null; then
        local az_version=$(az version --query '"azure-cli"' -o tsv 2>/dev/null)
        print_success "Azure CLI v$az_version"
    else
        print_error "Azure CLI nao instalado"
        ((errors++))
    fi

    # jq
    print_step "Verificando jq..."
    if command -v jq &> /dev/null; then
        print_success "jq $(jq --version 2>/dev/null)"
    else
        print_error "jq nao instalado"
        ((errors++))
    fi

    # kubectl
    print_step "Verificando kubectl..."
    if command -v kubectl &> /dev/null; then
        local kubectl_ver=$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' 2>/dev/null)
        print_success "kubectl $kubectl_ver"
    else
        print_error "kubectl nao instalado"
        ((errors++))
    fi

    # aks-preview extension
    print_step "Verificando extensao aks-preview..."
    local ext_ver=$(az extension show --name aks-preview --query version -o tsv 2>/dev/null)
    if [ -n "$ext_ver" ]; then
        print_success "aks-preview v$ext_ver"
    else
        print_warning "Extensao aks-preview nao encontrada. Instalando..."
        az extension add --name aks-preview --yes 2>/dev/null
        print_success "aks-preview instalada"
    fi

    # Azure login
    print_step "Verificando autenticacao Azure..."
    local account=$(az account show 2>/dev/null)
    if [ -n "$account" ]; then
        local sub_name=$(echo "$account" | jq -r '.name')
        print_success "Autenticado: $sub_name"
    else
        print_error "Nao autenticado no Azure. Execute: az login"
        ((errors++))
    fi

    if [ $errors -gt 0 ]; then
        echo ""
        print_error "Corrija os $errors erro(s) acima antes de continuar."
        exit 1
    fi

    return 0
}

#
#  FASE 2: SELECAO DO CLUSTER
#

select_cluster() {
    print_phase "2" "SELECAO DO CLUSTER AKS"

    print_step "Buscando clusters AKS na assinatura..."

    local clusters_json=$(az aks list --query "[].{name:name, resourceGroup:resourceGroup, location:location, kubernetesVersion:kubernetesVersion}" -o json 2>/dev/null)

    if [ -z "$clusters_json" ] || [ "$clusters_json" == "[]" ]; then
        print_error "Nenhum cluster AKS encontrado."
        exit 1
    fi

    local count=$(echo "$clusters_json" | jq '. | length')
    print_success "Encontrado(s) $count cluster(s)"
    echo ""

    # Mostrar clusters usando for loop com indice
    echo -e "${WHITE} Clusters disponiveis:${NC}"
    echo ""

    # Arrays para armazenar dados
    declare -a CLUSTER_NAMES=()
    declare -a CLUSTER_RGS=()
    declare -a CLUSTER_LOCATIONS=()

    for ((idx=0; idx<count; idx++)); do
        local name=$(echo "$clusters_json" | jq -r ".[$idx].name")
        local rg=$(echo "$clusters_json" | jq -r ".[$idx].resourceGroup")
        local location=$(echo "$clusters_json" | jq -r ".[$idx].location")
        local version=$(echo "$clusters_json" | jq -r ".[$idx].kubernetesVersion")

        # Armazenar nos arrays
        CLUSTER_NAMES+=("$name")
        CLUSTER_RGS+=("$rg")
        CLUSTER_LOCATIONS+=("$location")

        # Verificar se tem Istio
        local istio_mode=$(az aks show -g "$rg" -n "$name" --query "serviceMeshProfile.mode" -o tsv 2>/dev/null | tr -d '\r\n')
        local istio_badge=""

        if [[ "$istio_mode" == "Istio" ]]; then
            # Obter revisao atual
            local revision=$(az aks show -g "$rg" -n "$name" --query "serviceMeshProfile.istio.revisions[0]" -o tsv 2>/dev/null | tr -d '\r\n')
            istio_badge="${GREEN}[ISTIO: $revision]${NC}"
        else
            istio_badge="${GRAY}[SEM ISTIO]${NC}"
        fi

        local display_num=$((idx+1))
        echo -e "  ${CYAN}$display_num${NC} ${WHITE}$name${NC} $istio_badge"
        echo -e "    ${GRAY}RG: $rg | Regiao: $location | K8s: $version${NC}"
        echo ""
    done

    # Selecao
    echo -ne "${YELLOW} Selecione o cluster [1-$count]: ${NC}"
    read -r choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$count" ]; then
        print_error "Selecao invalida."
        exit 1
    fi

    local selected_idx=$((choice-1))
    CLUSTER_NAME="${CLUSTER_NAMES[$selected_idx]}"
    RESOURCE_GROUP="${CLUSTER_RGS[$selected_idx]}"
    LOCATION="${CLUSTER_LOCATIONS[$selected_idx]}"

    print_success "Cluster selecionado: $CLUSTER_NAME"

    # Configurar kubectl
    print_step "Configurando acesso kubectl..."

    # Detectar se estamos no WSL e configurar KUBECONFIG adequadamente
    if grep -qi microsoft /proc/version 2>/dev/null; then
        # WSL - usar caminho Windows convertido
        local win_user=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')
        export KUBECONFIG="/mnt/c/Users/${win_user}/.kube/config"
    fi

    az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing 2>/dev/null
    print_success "kubectl configurado"

    return 0
}

#
#  FASE 3: ANALISE DO CLUSTER
#

analyze_cluster() {
    print_phase "3" "ANALISE DO CLUSTER"

    print_step "Obtendo informacoes do cluster $CLUSTER_NAME..."

    # Obter versao do AKS
    AKS_VERSION=$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" \
        --query "kubernetesVersion" -o tsv 2>/dev/null | tr -d '\r\n')
    print_success "Versao Kubernetes: $AKS_VERSION"

    # Verificar status do Istio
    print_step "Verificando status do Istio..."
    local istio_mode
    istio_mode=$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" \
        --query "serviceMeshProfile.mode" -o tsv 2>/dev/null | tr -d '\r\n')

    if [[ "$istio_mode" == "Istio" ]]; then
        ISTIO_ENABLED=true
        CURRENT_REVISION=$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" \
            --query "serviceMeshProfile.istio.revisions[0]" -o tsv 2>/dev/null | tr -d '\r\n')

        print_success "Istio habilitado - Revisao atual: $CURRENT_REVISION"

        # Verificar upgrades disponiveis
        print_step "Verificando upgrades disponiveis..."
        AVAILABLE_UPGRADES=$(az aks mesh get-upgrades \
            -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" \
            --query "compatibleWith[0].revisions[0]" -o tsv 2>/dev/null | tr -d '\r\n')

        if [ -n "$AVAILABLE_UPGRADES" ] && [ "$AVAILABLE_UPGRADES" != "null" ]; then
            print_success "Upgrade disponivel: $AVAILABLE_UPGRADES"
        else
            print_success "Nenhum upgrade disponivel. Revisao atual e a mais recente."
            AVAILABLE_UPGRADES=""
        fi

        # Verificar namespaces com Istio
        print_step "Verificando namespaces com Istio habilitado..."
        local ns_list
        ns_list=$(kubectl get namespace -o json 2>/dev/null | \
            jq -r '.items[] | select(.metadata.labels | to_entries[] | .key | startswith("istio.io/rev")) | .metadata.name' 2>/dev/null)

        if [ -n "$ns_list" ]; then
            while IFS= read -r ns; do
                NAMESPACES_WITH_ISTIO+=("$ns")
            done <<< "$ns_list"
            print_success "Namespaces com Istio: ${#NAMESPACES_WITH_ISTIO[@]}"
            for ns in "${NAMESPACES_WITH_ISTIO[@]}"; do
                print_substep "$ns"
            done
        else
            print_warning "Nenhum namespace com Istio encontrado."
        fi

    else
        ISTIO_ENABLED=false
        echo -e "${WHITE} ${NC}${YELLOW}▲ ISTIO NAO HABILITADO${NC}"
        echo -e "${WHITE} ${NC}"
        echo -e "${WHITE} ${NC}${BLUE}▲ ACAO RECOMENDADA: Habilitar Istio Add-on${NC}"
        echo -e "${WHITE} ---${NC}"
        echo ""
    fi

    return 0
}

#
#  FASE 4A: FLUXO DE UPGRADE (CLUSTER COM ISTIO)
#

execute_upgrade_flow() {
    print_phase "4" "UPGRADE AUTOMATIZADO DO ISTIO"

    if [ -z "$AVAILABLE_UPGRADES" ] || [ "$AVAILABLE_UPGRADES" == "null" ]; then
        print_info "Seu cluster ja esta na versao mais recente do Istio."
        print_info "Revisao atual: $CURRENT_REVISION"
        echo ""
        print_success "Nenhuma acao necessaria!"
        return 0
    fi

    TARGET_REVISION="$AVAILABLE_UPGRADES"

    echo -e "${WHITE} O script ira executar automaticamente:${NC}"
    echo ""
    echo -e "  ${CYAN}1.${NC} Iniciar upgrade canary para ${GREEN}$TARGET_REVISION${NC}"
    echo -e "  ${CYAN}2.${NC} Migrar ${#NAMESPACES_WITH_ISTIO[@]} namespace(s) para a nova revisao"
    echo -e "  ${CYAN}3.${NC} Reiniciar workloads em cada namespace"
    echo -e "  ${CYAN}4.${NC} Validar saude dos pods"
    echo -e "  ${CYAN}5.${NC} Finalizar upgrade (remover revisao antiga)"
    echo ""

    if ! confirm "Deseja prosseguir com o upgrade de $CURRENT_REVISION → $TARGET_REVISION?"; then
        print_info "Operacao cancelada pelo usuario."
        return 0
    fi

    # PASSO 1: Iniciar upgrade canary
    echo ""
    print_action "PASSO 1/5: Iniciando upgrade canary..."

    if ! az aks mesh upgrade start \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER_NAME" \
        --revision "$TARGET_REVISION" 2>&1 | tee -a "$LOG_FILE"; then
        print_error "Falha ao iniciar upgrade canary."
        return 1
    fi

    print_success "Upgrade canary iniciado para $TARGET_REVISION"

    # Aguardar novo control plane
    print_wait "Aguardando deploy do novo control plane (30s)..."
    sleep 30

    # Verificar pods do Istiod
    print_step "Verificando pods do Istiod..."
    kubectl get pods -n aks-istio-system -l app=istiod -o wide 2>/dev/null
    echo ""

    # PASSO 2: Migrar namespaces
    echo ""
    print_action "PASSO 2/5: Migrando namespaces para a nova revisao..."

    for ns in "${NAMESPACES_WITH_ISTIO[@]}"; do
        print_substep "Migrando namespace: $ns"
        kubectl label namespace "$ns" istio.io/rev="$TARGET_REVISION" --overwrite 2>/dev/null
        print_success "Namespace $ns migrado"
    done

    # PASSO 3: Reiniciar workloads
    echo ""
    print_action "PASSO 3/5: Reiniciando workloads em cada namespace..."

    for ns in "${NAMESPACES_WITH_ISTIO[@]}"; do
        print_substep "Reiniciando deployments em: $ns"
        kubectl rollout restart deployment -n "$ns" 2>/dev/null
    done

    print_wait "Aguardando rollout dos workloads (30s)..."
    sleep 30

    # PASSO 4: Validar saude dos pods
    echo ""
    print_action "PASSO 4/5: Validando saude dos pods..."

    local validation_errors=0

    for ns in "${NAMESPACES_WITH_ISTIO[@]}"; do
        local not_ready
        not_ready=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | \
            grep -v "Running\|Completed" | wc -l)
        if [ "$not_ready" -gt 0 ]; then
            print_warning "Namespace $ns possui $not_ready pod(s) nao saudaveis"
            ((validation_errors++))
        else
            print_success "Namespace $ns: todos os pods saudaveis"
        fi
    done
    if [ $validation_errors -eq 0 ]; then
        echo ""
        print_action "PASSO 5/5: Finalizando upgrade..."

        if ! confirm "Validacao passou. Finalizar upgrade (remover revisao $CURRENT_REVISION)?"; then
            print_warning "Upgrade nao finalizado. Ambas revisoes permanecem ativas."
            print_info "Execute manualmente: az aks mesh upgrade complete -g $RESOURCE_GROUP -n $CLUSTER_NAME"
            return 0
        fi

        if az aks mesh upgrade complete \
            --resource-group "$RESOURCE_GROUP" \
            --name "$CLUSTER_NAME" \
            --yes 2>&1 | tee -a "$LOG_FILE"; then

            echo ""
            print_success "---"
            print_success "  UPGRADE CONCLUIDO COM SUCESSO!"
            print_success "  Revisao anterior: $CURRENT_REVISION (removida)"
            print_success "  Revisao atual: $TARGET_REVISION"
            print_success "---"
        else
            print_error "Falha ao finalizar upgrade."
            return 1
        fi
    else
        echo ""
        print_warning "Validacao encontrou $validation_errors problema(s)."
        print_info "Upgrade nao finalizado automaticamente."
        print_info "Corrija os problemas e execute manualmente:"
        echo -e "  ${CYAN}az aks mesh upgrade complete -g $RESOURCE_GROUP -n $CLUSTER_NAME${NC}"
        echo ""
        print_info "Ou faca rollback:"
        echo -e "  ${CYAN}az aks mesh upgrade rollback -g $RESOURCE_GROUP -n $CLUSTER_NAME${NC}"
    fi

    return 0
}

#
#  FASE 4B: FLUXO DE INSTALACAO (CLUSTER SEM ISTIO)
#

execute_install_flow() {
    print_phase "4" "INSTALACAO DO ISTIO ADD-ON"

    # Verificar CRDs existentes
    print_step "Verificando instalacoes anteriores do Istio..."
    local existing_crds
    existing_crds=$(kubectl get crd 2>/dev/null | grep -c "istio.io" 2>/dev/null || echo "0")
    existing_crds=$(echo "$existing_crds" | tr -d '\r\n' | head -1)

    if [ -n "$existing_crds" ] && [ "$existing_crds" -gt 0 ] 2>/dev/null; then
        print_warning "Encontrados $existing_crds CRDs de instalacao anterior do Istio."
        print_info "Recomendado: Remova antes de habilitar o add-on gerenciado."

        if ! confirm "Deseja continuar mesmo assim?"; then
            return 1
        fi
    fi

    # Obter revisoes compativeis
    print_step "Consultando revisoes compativeis para regiao $LOCATION..."

    local revisions_json
    revisions_json=$(az aks mesh get-revisions --location "$LOCATION" -o json 2>/dev/null)

    if [ -z "$revisions_json" ]; then
        print_error "Nao foi possivel obter revisoes disponiveis."
        return 1
    fi

    echo ""
    echo -e "${WHITE} Revisoes Istio disponiveis para $LOCATION:${NC}"
    echo ""

    local revision_list=()
    local rev_count
    rev_count=$(echo "$revisions_json" | jq '.meshRevisions | length' 2>/dev/null || echo "0")

    if [ "$rev_count" -eq 0 ]; then
        print_error "Nenhuma revisao compativel encontrada."
        return 1
    fi

    # Usar loop com indice (padrao mais robusto)
    for ((idx=0; idx<rev_count; idx++)); do
        local revision
        revision=$(echo "$revisions_json" | jq -r ".meshRevisions[$idx].revision")

        # Extrair versoes K8s compativeis de forma correta
        local k8s_versions
        k8s_versions=$(echo "$revisions_json" | jq -r ".meshRevisions[$idx].compatibleWith[0].versions | join(\", \")" 2>/dev/null || echo "N/A")

        local display_num=$((idx+1))
        echo -e "  ${CYAN}$display_num${NC} ${WHITE}$revision${NC} ${GREEN}✓ Compativel${NC}"
        echo -e "        ${GRAY}Versoes K8s: $k8s_versions${NC}"
        echo ""

        revision_list+=("$revision")
    done

    # Recomendar a ULTIMA (mais recente) - API retorna do mais antigo para mais novo
    local recommended="${revision_list[$((rev_count-1))]}"
    echo -e "  ${GREEN}★ Recomendado: $recommended (mais recente)${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}" Selecione a revisao [1-$rev_count] ou Enter para '$recommended': "${NC})" choice

    if [ -z "$choice" ]; then
        TARGET_REVISION="$recommended"
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $rev_count ]; then
        TARGET_REVISION="${revision_list[$((choice-1))]}"
    else
        print_error "Selecao invalida."
        return 1
    fi

    print_success "Revisao selecionada: $TARGET_REVISION"

    # Confirmar instalacao
    echo ""
    echo -e "${WHITE} O script ira executar automaticamente:${NC}"
    echo ""
    echo -e "  ${CYAN}1.${NC} Habilitar Istio Add-on com revisao ${GREEN}$TARGET_REVISION${NC}"
    echo -e "  ${CYAN}2.${NC} Aguardar deploy do control plane"
    echo -e "  ${CYAN}3.${NC} Validar instalacao"
    echo -e "  ${CYAN}4.${NC} Exibir proximos passos"
    echo ""

    if ! confirm "Deseja prosseguir com a instalacao?"; then
        print_info "Operacao cancelada pelo usuario."
        return 0
    fi
    echo ""
    print_action "PASSO 1/4: Habilitando Istio Add-on..."

    if ! az aks mesh enable \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER_NAME" \
        --revision "$TARGET_REVISION" 2>&1 | tee -a "$LOG_FILE"; then
        print_error "Falha ao habilitar Istio Add-on."
        return 1
    fi

    print_success "Istio Add-on habilitado"

    # PASSO 2: Aguardar deploy
    print_action "PASSO 2/4: Aguardando deploy do control plane (60s)..."
    sleep 60

    # PASSO 3: Validar
    print_action "PASSO 3/4: Validando instalacao..."

    local istiod_pods=$(kubectl get pods -n aks-istio-system -l app=istiod \
        --field-selector=status.phase=Running -o name 2>/dev/null | wc -l)

    if [ "$istiod_pods" -gt 0 ]; then
        print_success "Istiod esta running ($istiod_pods pods)"
        kubectl get pods -n aks-istio-system -l app=istiod 2>/dev/null
    else
        print_warning "Istiod ainda nao esta pronto. Verifique em alguns minutos."
    fi

    # PASSO 4: Proximos passos
    echo ""
    print_action "PASSO 4/4: Configuracao pos-instalacao"
    echo ""
    echo -e "${WHITE} ISTIO INSTALADO COM SUCESSO! ${NC}"
    echo -e "${NC}"
    echo -e "${CYAN} Proximos passos recomendados:${NC}"
    echo -e "${NC}"
    echo -e "${WHITE}1.${NC} Rotule namespaces para injecao de sidecar:"
    echo -e "  ${GRAY}kubectl label namespace <ns> istio.io/rev=$TARGET_REVISION${NC}"
    echo -e "${WHITE}2.${NC} Reinicie deployments para injetar sidecars:"
    echo -e "  ${GRAY}kubectl rollout restart deployment -n <ns>${NC}"
    echo -e "${WHITE}3.${NC} (Opcional) Habilite Ingress Gateway:"
    echo -e "  ${GRAY}az aks mesh enable-ingress-gateway \\"
    echo -e "  ${GRAY}  -g $RESOURCE_GROUP -n $CLUSTER_NAME \\"
    echo -e "  ${GRAY}  --ingress-gateway-type external${NC}"

    return 0
}

#
#  FASE 5: RESUMO FINAL
#

show_summary() {
    print_phase "5" "RESUMO DA OPERACAO"

    local line
    line=$(printf '=%.0s' {1..70})

    echo -e "${WHITE}$line${NC}"
    echo -e "${WHITE}  RESUMO FINAL${NC}"
    echo -e "${WHITE}$line${NC}"
    echo ""
    printf "${WHITE}  %-18s %-43s ${NC}%s\n" "Cluster"        "" "$CLUSTER_NAME"
    printf "${WHITE}  %-18s %-43s ${NC}%s\n" "Resource Group" "" "$RESOURCE_GROUP"
    printf "${WHITE}  %-18s %-43s ${NC}%s\n" "Operacao"       "" "$( [ "$ISTIO_ENABLED" = true ] && echo "Upgrade" || echo "Instalacao")"
    printf "${WHITE}  %-18s %-43s ${NC}%s\n" "Revisao Final"  "" "$TARGET_REVISION"
    echo ""
    printf "${WHITE}  %-18s %-43s ${NC}%s\n" "Log"            "" "$LOG_FILE"
    echo ""
    echo -e "${WHITE}$line${NC}"
    echo ""
}

#
#  FUNCAO PRINCIPAL
#

main() {
    # Criar log
    touch "$LOG_FILE"
    log "Sessao iniciada - v$VERSION"

    # Banner
    clear_screen
    show_banner

    # Fase 1: Validacao
    validate_environment

    # Fase 2: Selecao
    select_cluster

    # Fase 3: Analise
    analyze_cluster

    # Fase 4: Acao baseada no estado
    if [ "$ISTIO_ENABLED" = true ]; then
        execute_upgrade_flow
    else
        execute_install_flow
    fi

    # Fase 5: Resumo
    show_summary

    echo ""
    print_success "Operacao concluida! Obrigado por usar o AKS Istio Manager."
    echo ""

    log "Sessao finalizada"
}

#
#  TRATAMENTO DE SINAIS E EXECUCAO
#

trap 'echo ""; print_warning "Operacao cancelada pelo usuario."; exit 130' INT
trap 'echo ""; print_error "Erro inesperado."; exit 1' TERM

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
