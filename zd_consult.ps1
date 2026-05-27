<#
.SYNOPSIS
Gerencia a disponibilidade de Zonas de Disponibilidade e SKUs no Azure, registra a atividade em log

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\zd_consult.ps1 ou .\zd_consult.ps1

.EXAMPLE
Caso de Uso.:

Basico.: .\zd_consult.ps1

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab e use S e N em maíuscula para encerrar o script.

#>
# ==========================================================
#   CONSULTA DE ZONAS DE DISPONIBILIDADE PARA VMs
# ==========================================================

# Configs
$LOCATION = "brazilsouth"  # Pode alterar de acordo com a necessidade

$logDir  = "$env:USERPROFILE\AzureZoneQuery"
$logFile = "$logDir\ZoneQuery_$(Get-Date -Format 'yyyy-MM-dd').log"

if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# ----------------------------------------------------------
# Funcoes
# ----------------------------------------------------------

function Write-Log {
    param(
        [string]$Message,
        [string]$Status = "INFO"
    )
    $timestamp  = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    $logMessage = "$timestamp | $Status | $Message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage -ForegroundColor $(
        if     ($Status -eq "ERRO")    { "Red"    }
        elseif ($Status -eq "SUCESSO") { "Green"  }
        elseif ($Status -eq "AVISO")   { "Yellow" }
        else                           { "Gray"   }
    )
}

function Write-Section {
    param([string]$Title)
    $line = "=" * 55
    Write-Host ""
    Write-Host $line        -ForegroundColor Cyan
    Write-Host "  $Title"  -ForegroundColor Cyan
    Write-Host $line        -ForegroundColor Cyan
}

function Invoke-BuscarZDs {
    param(
        [string]$SkuName,
        [string]$SubscriptionName
    )

    Write-Log "Iniciando busca | SKU: $SkuName | Subscricao: $SubscriptionName" "INFO"

    # Logar na subscricao
    Write-Host ""
    Write-Log "Logando na subscricao.: $SubscriptionName" "INFO"

    $setOutput = az account set --subscription "$SubscriptionName" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Falha ao alterar para a subscricao '$SubscriptionName': $setOutput" "ERRO"
        Write-Host "  Verifique se o nome da subscricao esta correto." -ForegroundColor Red
        return
    }

    Write-Log "Subscricao ativa definida como.: $SubscriptionName" "SUCESSO"

    # Buscar SKUs
    Write-Log "Buscando informacoes para a SKU.: $SkuName na regiao $LOCATION" "INFO"

    $vmSkusJson = az vm list-skus `
        --location "$LOCATION" `
        --resource-type virtualMachines `
        --query "[?contains(name, '$SkuName')]" `
        --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Log "Erro ao consultar SKUs: $vmSkusJson" "ERRO"
        return
    }

    $vmSkus = $vmSkusJson | ConvertFrom-Json

    if ($vmSkus.Count -eq 0) {
        Write-Log "Nenhuma SKU encontrada contendo '$SkuName' na regiao $LOCATION" "AVISO"
        Write-Host "  Nenhuma SKU encontrada contendo '$SkuName' na regiao $LOCATION" -ForegroundColor Yellow
        return
    }

    # Exibir SKUs encontradas
    Write-Log "SKUs encontradas: $($vmSkus.Count)" "INFO"
    Write-Host ""
    Write-Host "  SKUs encontradas.:" -ForegroundColor White

    foreach ($sku in $vmSkus) {
        Write-Host "   - $($sku.name)" -ForegroundColor Gray
        Write-Log "  SKU: $($sku.name)" "INFO"
    }

    Write-Host ""

    # Extrair zonas de disponibilidade
    $zones = $vmSkus | ForEach-Object {
        $_.locationInfo | ForEach-Object {
            $_.zones
        }
    } | Where-Object { $_ } | Sort-Object -Unique

    if ($zones) {
        $availabilityZones = $zones -join ","
        Write-Host "  Zonas de disponibilidade.: $availabilityZones" -ForegroundColor Green
        Write-Log "Zonas de disponibilidade encontradas: $availabilityZones" "SUCESSO"
    } else {
        Write-Host "  Nenhuma zona de disponibilidade encontrada" -ForegroundColor Yellow
        Write-Log "Nenhuma zona de disponibilidade encontrada para SKU '$SkuName'" "AVISO"
    }

    Write-Host ""
}

# ==========================================================
# INICIO DO SCRIPT
# ==========================================================

try {
    Write-Section "CONSULTA DE ZONAS DE DISPONIBILIDADE PARA VMs"
    Write-Host "  Regiao Configurada.: $LOCATION" -ForegroundColor White
    Write-Host ""

    Write-Log "=== INICIO DA CONSULTA DE ZONAS DE DISPONIBILIDADE ===" "INFO"
    Write-Log "Regiao configurada: $LOCATION" "INFO"

    # Fluxo principal
    while ($true) {

        # Ler nome da subscricao
        Write-Host -NoNewline "  Digite o nome da subscricao.: "
        $SUBSCRIPTION_NAME = Read-Host

        if ([string]::IsNullOrWhiteSpace($SUBSCRIPTION_NAME)) {
            Write-Host "  Subscricao nao pode ser vazia. Tente Novamente." -ForegroundColor Yellow
            Write-Log "Subscricao vazia informada pelo usuario" "AVISO"
            Write-Host ""
            continue
        }

        # Ler SKU
        Write-Host -NoNewline "  Digite a SKU ou parte da SKU (Ex.: DS3_v2...).: "
        $SKU_NAME = Read-Host

        if ([string]::IsNullOrWhiteSpace($SKU_NAME)) {
            Write-Host "  SKU nao pode ser vazia. Tente Novamente." -ForegroundColor Yellow
            Write-Log "SKU vazia informada pelo usuario" "AVISO"
            Write-Host ""
            continue
        }

        Write-Host ""
        Invoke-BuscarZDs -SkuName $SKU_NAME -SubscriptionName $SUBSCRIPTION_NAME

        # Perguntar se deseja continuar
        Write-Host -NoNewline "  Deseja consultar uma nova/outra SKU? (S/N).: "
        $resposta = Read-Host

        if ($resposta -match '^[SsYy]') {
            Write-Log "Usuario optou por continuar" "INFO"
            Write-Host ""
            continue
        } else {
            Write-Log "Usuario optou por finalizar" "INFO"
            Write-Host "  Finalizando..." -ForegroundColor Yellow
            break
        }
    }

    Write-Log "=== FIM DA CONSULTA DE ZONAS DE DISPONIBILIDADE ===" "INFO"
    Write-Host ""
    Write-Host "  Log salvo em: $logFile" -ForegroundColor Green
    Write-Host ""

    exit 0

} catch {
    $errorMsg = "Erro na linha $($_.InvocationInfo.ScriptLineNumber): $($Error[0])"
    Write-Log $errorMsg "ERRO"
    Write-Host "ERRO: $errorMsg" -ForegroundColor Red
    exit 1
}