<#
.SYNOPSIS
Gerencia o uso do Istio em clusters AKS e registra a atividade em log.

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\check_swap.ps1 ou .\aks_istio_manager.ps1

.EXAMPLE
Caso de Uso.:

Basico.: .\aks_istio_manager.ps1

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab e use S e N em maíuscula para encerrar o script.

#>

# Configs globais
$script:VERSION = "3.0.0"
$script:LOG_FILE = "/tmp/istio-manager-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Estado do cluster
$script:RESOURCE_GROUP = ""
$script:CLUSTER_NAME = ""
$script:LOCATION = ""
$script:AKS_VERSION = ""
$script:ISTIO_ENABLED = $false
$script:CURRENT_REVISION = ""
$script:TARGET_REVISION = ""
$script:AVAILABLE_UPGRADES = ""
$script:NAMESPACES_WITH_ISTIO = @()

# Configs de retry
$script:MAX_RETRIES = 3
$script:RETRY_DELAY = 10

# Cores e formatacao (PowerShell)
if ($Host.UI.RawUI.SupportsVirtualTerminal) {
    $script:RED = "`e[0;31m"
    $script:GREEN = "`e[0;32m"
    $script:YELLOW = "`e[1;33m"
    $script:BLUE = "`e[0;34m"
    $script:PURPLE = "`e[0;35m"
    $script:CYAN = "`e[0;36m"
    $script:WHITE = "`e[1;37m"
    $script:GRAY = "`e[0;90m"
    $script:BOLD = "`e[1m"
    $script:NC = "`e[0m"
} else {
    $script:RED = $script:GREEN = $script:YELLOW = $script:BLUE = ""
    $script:PURPLE = $script:CYAN = $script:WHITE = $script:GRAY = ""
    $script:BOLD = $script:NC = ""
}

<#
.SYNOPSIS
    Registra mensagem no arquivo de log
#>
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] $Message" | Out-File -FilePath $script:LOG_FILE -Append
}

<#
.SYNOPSIS
    Limpa a tela
#>
function Clear-Screen {
    Clear-Host
}

<#
.SYNOPSIS
    Exibe o banner de abertura
#>
function Show-Banner {
    Write-Host
    Write-Host "$($script:CYAN)$('=' * 70)$($script:NC)"
    Write-Host "$($script:CYAN)$($script:NC)"
    Write-Host "  $($script:BLUE)AKS ISTIO$($script:NC)"
    Write-Host "$($script:CYAN)$($script:NC)"
    Write-Host "  $($script:PURPLE)SERVICE$($script:NC)"
    Write-Host "$($script:CYAN)$($script:NC)"
    Write-Host "  $($script:WHITE)MESH$($script:NC)"
    Write-Host "$($script:CYAN)$($script:NC)"
    Write-Host "$($script:CYAN)$('=' * 70)$($script:NC)"
    Write-Host "  $($script:GREEN)※$($script:NC) Azure Kubernetes Service - Istio Add-on Intelligent Manager"
    Write-Host "  $($script:CYAN)v$($script:VERSION)$($script:NC)"
    Write-Host "$($script:CYAN)$('=' * 70)$($script:NC)"
    Write-Host
}

<#
.SYNOPSIS
    Exibe cabeçalho de fase
#>
function Write-Phase {
    param(
        [string]$Phase,
        [string]$Description
    )
    Write-Host
    Write-Host "$($script:CYAN)$('=' * 70)$($script:NC)"
    Write-Host "$($script:WHITE)$($script:BOLD)  FASE $Phase : $Description$($script:NC)"
    Write-Host "$($script:CYAN)$('=' * 70)$($script:NC)"
    Write-Host ""
    Write-Log "FASE $Phase : $Description"
}

<#
.SYNOPSIS
    Exibe passo normal
#>
function Write-Step {
    param([string]$Message)
    Write-Host "$($script:CYAN) ►$($script:NC) $Message"
    Write-Log "STEP: $Message"
}

<#
.SYNOPSIS
    Exibe subpasso (indentado)
#>
function Write-Substep {
    param([string]$Message)
    Write-Host "$($script:GRAY) ├$($script:NC) $Message"
}

<#
.SYNOPSIS
    Exibe mensagem de sucesso
#>
function Write-Success {
    param([string]$Message)
    Write-Host "$($script:GREEN) ✓ $Message$($script:NC)"
    Write-Log "SUCCESS: $Message"
}

<#
.SYNOPSIS
    Exibe mensagem de erro
#>
function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "$($script:RED) ✗ $Message$($script:NC)"
    Write-Log "ERROR: $Message"
}

<#
.SYNOPSIS
    Exibe mensagem de aviso
#>
function Write-WarningMsg {
    param([string]$Message)
    Write-Host "$($script:YELLOW) ▲ $Message$($script:NC)"
    Write-Log "WARNING: $Message"
}

<#
.SYNOPSIS
    Exibe mensagem informativa
#>
function Write-Info {
    param([string]$Message)
    Write-Host "$($script:BLUE) ℹ $Message$($script:NC)"
    Write-Log "INFO: $Message"
}

<#
.SYNOPSIS
    Exibe mensagem de ação
#>
function Write-Action {
    param([string]$Message)
    Write-Host "$($script:PURPLE) ◉ $Message$($script:NC)"
    Write-Log "ACTION: $Message"
}

<#
.SYNOPSIS
    Exibe mensagem de espera
#>
function Write-Wait {
    param([string]$Message)
    Write-Host "$($script:GRAY) ⏱ $Message$($script:NC)"
}

<#
.SYNOPSIS
    Exibe spinner animado durante execução de comando
#>
function Show-Spinner {
    param(
        [scriptblock]$ScriptBlock,
        [string]$Message = "Aguarde..."
    )
    Write-Host "$($script:CYAN) ⠋ $Message$($script:NC)" -NoNewline
    $job = Start-Job -ScriptBlock $ScriptBlock
    $spinChars = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
    $i = 0
    while ($job.State -eq 'Running') {
        Write-Host "`r$($script:CYAN) $($spinChars[$i % $spinChars.Length]) $Message$($script:NC)" -NoNewline
        $i++
        Start-Sleep -Milliseconds 100
    }
    Write-Host "`r" -NoNewline
    $result = Receive-Job -Job $job -Wait -AutoRemoveJob
    return $result
}

<#
.SYNOPSIS
    Solicita confirmação do usuário
#>
function Confirm-Action {
    param([string]$Message)
    Write-Host
    $response = Read-Host "$($script:YELLOW) ? $Message [S/n]: $($script:NC)"
    if ([string]::IsNullOrWhiteSpace($response)) { $response = "s" }
    return ($response -match '^[sS]$')
}

<#
.SYNOPSIS
    Fase 1: Validação do ambiente
#>
function Validate-Environment {
    Write-Phase "1" "VALIDACAO DO AMBIENTE"
    $errors = 0

    # Azure CLI
    Write-Step "Verificando Azure CLI..."
    $azPath = (Get-Command az -ErrorAction SilentlyContinue)
    if ($azPath) {
        $azVersion = az version --query '"azure-cli"' -o tsv 2>$null
        Write-Success "Azure CLI v$azVersion"
    } else {
        Write-ErrorMsg "Azure CLI nao instalado"
        $errors++
    }

    # kubectl
    Write-Step "Verificando kubectl..."
    $kubectlPath = (Get-Command kubectl -ErrorAction SilentlyContinue)
    if ($kubectlPath) {
        $kubectlVer = kubectl version --client -o json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty clientVersion | Select-Object -ExpandProperty gitVersion
        Write-Success "kubectl $kubectlVer"
    } else {
        Write-ErrorMsg "kubectl nao instalado"
        $errors++
    }

    # Verificar extensao aks-preview
    Write-Step "Verificando extensao aks-preview..."
    $extVer = az extension show --name aks-preview --query version -o tsv 2>$null
    if ($extVer) {
        Write-Success "aks-preview v$extVer"
    } else {
        Write-WarningMsg "Extensao aks-preview nao encontrada. Instalando..."
        az extension add --name aks-preview --yes 2>&1 | Out-Null
        Write-Success "aks-preview instalada"
    }

    # Azure login
    Write-Step "Verificando autenticacao Azure..."
    $account = az account show 2>$null | ConvertFrom-Json
    if ($account) {
        Write-Success "Autenticado: $($account.name)"
    } else {
        Write-ErrorMsg "Nao autenticado no Azure. Execute: az login"
        $errors++
    }

    if ($errors -gt 0) {
        Write-Host
        Write-ErrorMsg "Corrija os $errors erro(s) acima antes de continuar."
        exit 1
    }

    return $true
}

<#
.SYNOPSIS
    Fase 2: Seleção do cluster AKS
#>
function Select-Cluster {
    Write-Phase "2" "SELECAO DO CLUSTER AKS"

    Write-Step "Buscando clusters AKS na assinatura..."

    $clustersJson = az aks list --query "[].{name:name, resourceGroup:resourceGroup, location:location, kubernetesVersion:kubernetesVersion}" -o json 2>$null
    $clusters = $clustersJson | ConvertFrom-Json

    if (-not $clusters -or $clusters.Count -eq 0) {
        Write-ErrorMsg "Nenhum cluster AKS encontrado."
        exit 1
    }

    Write-Success "Encontrado(s) $($clusters.Count) cluster(s)"
    Write-Host ""

    # Exibir clusters
    Write-Host "$($script:WHITE) Clusters disponiveis:$($script:NC)"
    Write-Host ""

    for ($idx = 0; $idx -lt $clusters.Count; $idx++) {
        $cluster = $clusters[$idx]
        $displayNum = $idx + 1

        $istioMode = az aks show -g $cluster.resourceGroup -n $cluster.name --query "serviceMeshProfile.mode" -o tsv 2>$null
        $istioMode = $istioMode.Trim()

        if ($istioMode -eq "Istio") {
            $revision = az aks show -g $cluster.resourceGroup -n $cluster.name --query "serviceMeshProfile.istio.revisions[0]" -o tsv 2>$null
            $revision = $revision.Trim()
            $istioBadge = "$($script:GREEN)[ISTIO: $revision]$($script:NC)"
        } else {
            $istioBadge = "$($script:GRAY)[SEM ISTIO]$($script:NC)"
        }

        Write-Host "  $($script:CYAN)$displayNum$($script:NC) $($script:WHITE)$($cluster.name)$($script:NC) $istioBadge"
        Write-Host "    $($script:GRAY)RG: $($cluster.resourceGroup) | Regiao: $($cluster.location) | K8s: $($cluster.kubernetesVersion)$($script:NC)"
        Write-Host ""
    }

    # Selecao
    $choice = Read-Host "$($script:YELLOW) Selecione o cluster [1-$($clusters.Count)]:$($script:NC)"
    if ($choice -notmatch '^\d+$' -or [int]$choice -lt 1 -or [int]$choice -gt $clusters.Count) {
        Write-ErrorMsg "Selecao invalida."
        exit 1
    }

    $selectedIdx = [int]$choice - 1
    $selected = $clusters[$selectedIdx]
    $script:CLUSTER_NAME = $selected.name
    $script:RESOURCE_GROUP = $selected.resourceGroup
    $script:LOCATION = $selected.location

    Write-Success "Cluster selecionado: $script:CLUSTER_NAME"

    # Configurar kubectl
    Write-Step "Configurando acesso kubectl..."
    az aks get-credentials --resource-group $script:RESOURCE_GROUP --name $script:CLUSTER_NAME --overwrite-existing 2>&1 | Out-Null
    Write-Success "kubectl configurado"

    return $true
}

<#
.SYNOPSIS
    Fase 3: Análise do cluster
#>
function Analyze-Cluster {
    Write-Phase "3" "ANALISE DO CLUSTER"

    Write-Step "Obtendo informacoes do cluster $script:CLUSTER_NAME..."

    $script:AKS_VERSION = az aks show -g $script:RESOURCE_GROUP -n $script:CLUSTER_NAME --query "kubernetesVersion" -o tsv 2>$null
    $script:AKS_VERSION = $script:AKS_VERSION.Trim()
    Write-Success "Versao Kubernetes: $script:AKS_VERSION"

    Write-Step "Verificando status do Istio..."
    $istioMode = az aks show -g $script:RESOURCE_GROUP -n $script:CLUSTER_NAME --query "serviceMeshProfile.mode" -o tsv 2>$null
    $istioMode = $istioMode.Trim()

    if ($istioMode -eq "Istio") {
        $script:ISTIO_ENABLED = $true
        $script:CURRENT_REVISION = az aks show -g $script:RESOURCE_GROUP -n $script:CLUSTER_NAME --query "serviceMeshProfile.istio.revisions[0]" -o tsv 2>$null
        $script:CURRENT_REVISION = $script:CURRENT_REVISION.Trim()

        Write-Success "Istio habilitado - Revisao atual: $script:CURRENT_REVISION"

        Write-Step "Verificando upgrades disponiveis..."
        $script:AVAILABLE_UPGRADES = az aks mesh get-upgrades -g $script:RESOURCE_GROUP -n $script:CLUSTER_NAME --query "compatibleWith[0].revisions[0]" -o tsv 2>$null
        $script:AVAILABLE_UPGRADES = $script:AVAILABLE_UPGRADES.Trim()

        if ($script:AVAILABLE_UPGRADES -and $script:AVAILABLE_UPGRADES -ne "null") {
            Write-Success "Upgrade disponivel: $script:AVAILABLE_UPGRADES"
        } else {
            Write-Success "Nenhum upgrade disponivel. Revisao atual e a mais recente."
            $script:AVAILABLE_UPGRADES = ""
        }

        Write-Step "Verificando namespaces com Istio habilitado..."
        $nsList = kubectl get namespace -o json 2>$null | ConvertFrom-Json
        if ($nsList -and $nsList.items) {
            $script:NAMESPACES_WITH_ISTIO = $nsList.items | Where-Object {
                $_.metadata.labels.PSObject.Properties.Name -match "^istio.io/rev"
            } | ForEach-Object { $_.metadata.name }

            if ($script:NAMESPACES_WITH_ISTIO.Count -gt 0) {
                Write-Success "Namespaces com Istio: $($script:NAMESPACES_WITH_ISTIO.Count)"
                foreach ($ns in $script:NAMESPACES_WITH_ISTIO) {
                    Write-Substep $ns
                }
            } else {
                Write-WarningMsg "Nenhum namespace com Istio encontrado."
            }
        } else {
            Write-WarningMsg "Nenhum namespace com Istio encontrado."
        }
    } else {
        $script:ISTIO_ENABLED = $false
        Write-Host "$($script:WHITE) $($script:NC)$($script:YELLOW)▲ ISTIO NAO HABILITADO$($script:NC)"
        Write-Host "$($script:WHITE) $($script:NC)"
        Write-Host "$($script:WHITE) $($script:NC)$($script:BLUE)▲ ACAO RECOMENDADA: Habilitar Istio Add-on$($script:NC)"
        Write-Host "$($script:WHITE) ---$($script:NC)"
        Write-Host ""
    }

    return $true
}

<#
.SYNOPSIS
    Fase 4A: Fluxo de upgrade (cluster com Istio)
#>
function Execute-UpgradeFlow {
    Write-Phase "4" "UPGRADE AUTOMATIZADO DO ISTIO"

    if (-not $script:AVAILABLE_UPGRADES -or $script:AVAILABLE_UPGRADES -eq "null") {
        Write-Info "Seu cluster ja esta na versao mais recente do Istio."
        Write-Info "Revisao atual: $script:CURRENT_REVISION"
        Write-Host ""
        Write-Success "Nenhuma acao necessaria!"
        return $true
    }

    $script:TARGET_REVISION = $script:AVAILABLE_UPGRADES

    Write-Host "$($script:WHITE) O script ira executar automaticamente:$($script:NC)"
    Write-Host ""
    Write-Host "  $($script:CYAN)1.$($script:NC) Iniciar upgrade canary para $($script:GREEN)$script:TARGET_REVISION$($script:NC)"
    Write-Host "  $($script:CYAN)2.$($script:NC) Migrar $($script:NAMESPACES_WITH_ISTIO.Count) namespace(s) para a nova revisao"
    Write-Host "  $($script:CYAN)3.$($script:NC) Reiniciar workloads em cada namespace"
    Write-Host "  $($script:CYAN)4.$($script:NC) Validar saude dos pods"
    Write-Host "  $($script:CYAN)5.$($script:NC) Finalizar upgrade (remover revisao antiga)"
    Write-Host ""

    if (-not (Confirm-Action "Deseja prosseguir com o upgrade de $script:CURRENT_REVISION → $script:TARGET_REVISION?")) {
        Write-Info "Operacao cancelada pelo usuario."
        return $true
    }

    # PASSO 1: Iniciar upgrade canary
    Write-Host ""
    Write-Action "PASSO 1/5: Iniciando upgrade canary..."

    $upgradeResult = az aks mesh upgrade start --resource-group $script:RESOURCE_GROUP --name $script:CLUSTER_NAME --revision $script:TARGET_REVISION 2>&1 | Tee-Object -FilePath $script:LOG_FILE -Append
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Falha ao iniciar upgrade canary."
        return $false
    }

    Write-Success "Upgrade canary iniciado para $script:TARGET_REVISION"

    Write-Wait "Aguardando deploy do novo control plane (30s)..."
    Start-Sleep -Seconds 30

    Write-Step "Verificando pods do Istiod..."
    kubectl get pods -n aks-istio-system -l app=istiod -o wide 2>$null
    Write-Host ""

    # PASSO 2: Migrar namespaces
    Write-Host ""
    Write-Action "PASSO 2/5: Migrando namespaces para a nova revisao..."

    foreach ($ns in $script:NAMESPACES_WITH_ISTIO) {
        Write-Substep "Migrando namespace: $ns"
        kubectl label namespace $ns "istio.io/rev=$($script:TARGET_REVISION)" --overwrite 2>$null
        Write-Success "Namespace $ns migrado"
    }

    # PASSO 3: Reiniciar workloads
    Write-Host ""
    Write-Action "PASSO 3/5: Reiniciando workloads em cada namespace..."

    foreach ($ns in $script:NAMESPACES_WITH_ISTIO) {
        Write-Substep "Reiniciando deployments em: $ns"
        kubectl rollout restart deployment -n $ns 2>$null
    }

    Write-Wait "Aguardando rollout dos workloads (30s)..."
    Start-Sleep -Seconds 30

    # PASSO 4: Validar saude dos pods
    Write-Host ""
    Write-Action "PASSO 4/5: Validando saude dos pods..."

    $validationErrors = 0
    foreach ($ns in $script:NAMESPACES_WITH_ISTIO) {
        $pods = kubectl get pods -n $ns --no-headers 2>$null
        $notReady = ($pods | Where-Object { $_ -notmatch "Running|Completed" }).Count
        if ($notReady -gt 0) {
            Write-WarningMsg "Namespace $ns possui $notReady pod(s) nao saudaveis"
            $validationErrors++
        } else {
            Write-Success "Namespace $ns: todos os pods saudaveis"
        }
    }

    if ($validationErrors -eq 0) {
        Write-Host ""
        Write-Action "PASSO 5/5: Finalizando upgrade..."

        if (-not (Confirm-Action "Validacao passou. Finalizar upgrade (remover revisao $script:CURRENT_REVISION)?")) {
            Write-WarningMsg "Upgrade nao finalizado. Ambas revisoes permanecem ativas."
            Write-Info "Execute manualmente: az aks mesh upgrade complete -g $script:RESOURCE_GROUP -n $script:CLUSTER_NAME"
            return $true
        }

        $completeResult = az aks mesh upgrade complete --resource-group $script:RESOURCE_GROUP --name $script:CLUSTER_NAME --yes 2>&1 | Tee-Object -FilePath $script:LOG_FILE -Append
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Success "---"
            Write-Success "  UPGRADE CONCLUIDO COM SUCESSO!"
            Write-Success "  Revisao anterior: $script:CURRENT_REVISION (removida)"
            Write-Success "  Revisao atual: $script:TARGET_REVISION"
            Write-Success "---"
        } else {
            Write-ErrorMsg "Falha ao finalizar upgrade."
            return $false
        }
    } else {
        Write-Host ""
        Write-WarningMsg "Validacao encontrou $validationErrors problema(s)."
        Write-Info "Upgrade nao finalizado automaticamente."
        Write-Info "Corrija os problemas e execute manualmente:"
        Write-Host "  $($script:CYAN)az aks mesh upgrade complete -g $script:RESOURCE_GROUP -n $script:CLUSTER_NAME$($script:NC)"
        Write-Host ""
        Write-Info "Ou faca rollback:"
        Write-Host "  $($script:CYAN)az aks mesh upgrade rollback -g $script:RESOURCE_GROUP -n $script:CLUSTER_NAME$($script:NC)"
    }

    return $true
}

<#
.SYNOPSIS
    Fase 4B: Fluxo de instalacao (cluster sem Istio)
#>
function Execute-InstallFlow {
    Write-Phase "4" "INSTALACAO DO ISTIO ADD-ON"

    Write-Step "Verificando instalacoes anteriores do Istio..."
    $existingCrds = kubectl get crd 2>$null | Where-Object { $_ -match "istio.io" } | Measure-Object | Select-Object -ExpandProperty Count

    if ($existingCrds -and $existingCrds -gt 0) {
        Write-WarningMsg "Encontrados $existingCrds CRDs de instalacao anterior do Istio."
        Write-Info "Recomendado: Remova antes de habilitar o add-on gerenciado."

        if (-not (Confirm-Action "Deseja continuar mesmo assim?")) {
            return $false
        }
    }

    Write-Step "Consultando revisoes compativeis para regiao $script:LOCATION..."

    $revisionsJson = az aks mesh get-revisions --location $script:LOCATION -o json 2>$null
    if (-not $revisionsJson) {
        Write-ErrorMsg "Nao foi possivel obter revisoes disponiveis."
        return $false
    }

    $revisionsData = $revisionsJson | ConvertFrom-Json
    $revisionList = @()

    Write-Host ""
    Write-Host "$($script:WHITE) Revisoes Istio disponiveis para $script:LOCATION:$($script:NC)"
    Write-Host ""

    $revCount = $revisionsData.meshRevisions.Count
    if ($revCount -eq 0) {
        Write-ErrorMsg "Nenhuma revisao compativel encontrada."
        return $false
    }

    for ($idx = 0; $idx -lt $revCount; $idx++) {
        $rev = $revisionsData.meshRevisions[$idx]
        $displayNum = $idx + 1
        $k8sVersions = $rev.compatibleWith[0].versions -join ", "
        Write-Host "  $($script:CYAN)$displayNum$($script:NC) $($script:WHITE)$($rev.revision)$($script:NC) $($script:GREEN)✓ Compativel$($script:NC)"
        Write-Host "        $($script:GRAY)Versoes K8s: $k8sVersions$($script:NC)"
        Write-Host ""
        $revisionList += $rev.revision
    }

    $recommended = $revisionList[-1]
    Write-Host "  $($script:GREEN)★ Recomendado: $recommended (mais recente)$($script:NC)"
    Write-Host ""

    $choice = Read-Host "$($script:YELLOW) Selecione a revisao [1-$revCount] ou Enter para '$recommended':$($script:NC)"

    if ([string]::IsNullOrWhiteSpace($choice)) {
        $script:TARGET_REVISION = $recommended
    } elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $revCount) {
        $script:TARGET_REVISION = $revisionList[[int]$choice - 1]
    } else {
        Write-ErrorMsg "Selecao invalida."
        return $false
    }

    Write-Success "Revisao selecionada: $script:TARGET_REVISION"

    Write-Host ""
    Write-Host "$($script:WHITE) O script ira executar automaticamente:$($script:NC)"
    Write-Host ""
    Write-Host "  $($script:CYAN)1.$($script:NC) Habilitar Istio Add-on com revisao $($script:GREEN)$script:TARGET_REVISION$($script:NC)"
    Write-Host "  $($script:CYAN)2.$($script:NC) Aguardar deploy do control plane"
    Write-Host "  $($script:CYAN)3.$($script:NC) Validar instalacao"
    Write-Host "  $($script:CYAN)4.$($script:NC) Exibir proximos passos"
    Write-Host ""

    if (-not (Confirm-Action "Deseja prosseguir com a instalacao?")) {
        Write-Info "Operacao cancelada pelo usuario."
        return $true
    }

    Write-Host ""
    Write-Action "PASSO 1/4: Habilitando Istio Add-on..."

    $enableResult = az aks mesh enable --resource-group $script:RESOURCE_GROUP --name $script:CLUSTER_NAME --revision $script:TARGET_REVISION 2>&1 | Tee-Object -FilePath $script:LOG_FILE -Append
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Falha ao habilitar Istio Add-on."
        return $false
    }

    Write-Success "Istio Add-on habilitado"

    Write-Action "PASSO 2/4: Aguardando deploy do control plane (60s)..."
    Start-Sleep -Seconds 60

    Write-Action "PASSO 3/4: Validando instalacao..."

    $istiodPods = kubectl get pods -n aks-istio-system -l app=istiod --field-selector=status.phase=Running -o name 2>$null | Measure-Object | Select-Object -ExpandProperty Count

    if ($istiodPods -gt 0) {
        Write-Success "Istiod esta running ($istiodPods pods)"
        kubectl get pods -n aks-istio-system -l app=istiod 2>$null
    } else {
        Write-WarningMsg "Istiod ainda nao esta pronto. Verifique em alguns minutos."
    }

    Write-Host ""
    Write-Action "PASSO 4/4: Configuracao pos-instalacao"
    Write-Host ""
    Write-Host "$($script:WHITE) ISTIO INSTALADO COM SUCESSO! $($script:NC)"
    Write-Host ""
    Write-Host "$($script:CYAN) Proximos passos recomendados:$($script:NC)"
    Write-Host ""
    Write-Host "$($script:WHITE)1.$($script:NC) Rotule namespaces para injecao de sidecar:"
    Write-Host "  $($script:GRAY)kubectl label namespace <ns> istio.io/rev=$script:TARGET_REVISION$($script:NC)"
    Write-Host "$($script:WHITE)2.$($script:NC) Reinicie deployments para injetar sidecars:"
    Write-Host "  $($script:GRAY)kubectl rollout restart deployment -n <ns>$($script:NC)"
    Write-Host "$($script:WHITE)3.$($script:NC) (Opcional) Habilite Ingress Gateway:"
    Write-Host "  $($script:GRAY)az aks mesh enable-ingress-gateway \"
    Write-Host "    -g $script:RESOURCE_GROUP -n $script:CLUSTER_NAME \"
    Write-Host "    --ingress-gateway-type external$($script:NC)"

    return $true
}

<#
.SYNOPSIS
    Fase 5: Resumo final
#>
function Show-Summary {
    Write-Phase "5" "RESUMO DA OPERACAO"

    $line = '=' * 70
    $operation = if ($script:ISTIO_ENABLED) { "Upgrade" } else { "Instalacao" }
    $revision = if ($script:TARGET_REVISION) { $script:TARGET_REVISION } else { $script:CURRENT_REVISION }

    Write-Host "$($script:WHITE)$line$($script:NC)"
    Write-Host "$($script:WHITE)  RESUMO FINAL$($script:NC)"
    Write-Host "$($script:WHITE)$line$($script:NC)"
    Write-Host ""
    Write-Host "$($script:WHITE)  Cluster        $($script:NC)$script:CLUSTER_NAME"
    Write-Host "$($script:WHITE)  Resource Group $($script:NC)$script:RESOURCE_GROUP"
    Write-Host "$($script:WHITE)  Operacao       $($script:NC)$operation"
    Write-Host "$($script:WHITE)  Revisao Final  $($script:NC)$revision"
    Write-Host ""
    Write-Host "$($script:WHITE)  Log            $($script:NC)$script:LOG_FILE"
    Write-Host ""
    Write-Host "$($script:WHITE)$line$($script:NC)"
    Write-Host ""
}

<#
.SYNOPSIS
    Funcao principal
#>
function Main {
    # Criar log
    New-Item -Path $script:LOG_FILE -ItemType File -Force | Out-Null
    Write-Log "Sessao iniciada - v$script:VERSION"

    # Banner
    Clear-Screen
    Show-Banner

    # Fase 1: Validação
    if (-not (Validate-Environment)) { exit 1 }

    # Fase 2: Seleção
    if (-not (Select-Cluster)) { exit 1 }

    # Fase 3: Análise
    if (-not (Analyze-Cluster)) { exit 1 }

    # Fase 4: Ação baseada no estado
    if ($script:ISTIO_ENABLED) {
        Execute-UpgradeFlow
    } else {
        Execute-InstallFlow
    }

    # Fase 5: Resumo
    Show-Summary

    Write-Host ""
    Write-Success "Operacao concluida! Obrigado por usar o AKS Istio Manager."
    Write-Host ""

    Write-Log "Sessao finalizada"
}

# Tratamento de sinais
try {
    Main @args
} catch {
    Write-WarningMsg "Operacao cancelada pelo usuario ou erro inesperado."
    exit 1
}