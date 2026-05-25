#
# Script em Bash que consulta zonas de disponibilidade de SKUs de VMs no Azure, permite várias consultas
#
#
# Para usar.:
# 1-) Torne o script executavel.: chmod +x 
#
# 2-) Como usar.:
#
# Uso Basico.:
# ./zd_consult.sh
#
# Autor.: Joao Rafael F. Bonilha - Curso de Bash
#
# ATENCAO.: Este script devera ser usado em ambiente de testes/lab
#
# !/bin/Bash

# Pode alterar de acordo com a necessidade
LOCATION="brazilsouth"

echo "=== Consulta de Zonas de Disponibilidade para VMs ==="
echo "Regiao Configurada.: $LOCATION"
echo 

# Funcao de busca de ZDs

buscar_zds() {
    local sku_name="$1"
	local subscription_name="$2"
	
	echo " Logando na subscricao.: $subscription_name..."
	az account set --subscription "subscription_name"
	
	if [ $? -ne 0 ]; then
	    echo "Falha ao alterar para a subscricao '$subscription_name'. Verifique se o nome esta correto."
		return
	fi
	
	echo "Subscricao ativa definida como.: $subscription_name"
	echo "Buscando informacoes para a SKU.: $sku_name..."
	
	vmSkus=$(az vm list-skus \ 
	    --location "$LOCATION" \
		--resource-type virtualMachines \
		--query "[?contains(name, '$sku_name')]" \
		--output json)
		
	if [ "$(echo "vmSkus" | jq '. | length')" -eq 0 ]; then
	    echo "Nenhuma SKU encontrada contendo '$sku_name' na regiao $LOCATION"
		return
	fi
	
	echo " SKUs encontradas.: "
	echo "$vmSkus" | jq -r '.[].name' | sed 's/^/ -/'
	echo
	
	zones=$(echo "$vmSkus" | jq -r '.[].locationInfo[]zones[]?' | sort -u)
	
	if [ -n "$zones" ]; then
	  AvailabilityZones=$(echo "$zones" | tr '\n' ',' | sed 's/,$//')
	  echo "Zonas de disponibilidade.: $AvailabilityZones"
	else
	  echo "Nenhuma zona de disponibilidade encontrada"
	fi
	echo
}

# Fluxo principal do Script.:

while true; do
    echo -n "Digite o nome da subscricao.: "
	read -r SUBSCRIPTION_NAME 
	if [ -z "$SUBSCRIPTION_NAME" ]; then
	    echo "Subscricao nao pode ser vazia. Tente Novamente."
		echo
		continue
	fi
	
	echo -n "Digite a SKU ou parte da SKU (Ex.: DS3_v2...).:"
	read -r SKU_NAME 
	
	if [ -z "$SKU_NAME" ]; then
	    echo "SKU nao pode ser vazia. Tente Novamente."
		echo
		continue
	fi
	
	echo
	buscar_zds "$SKU_NAME" "$SUBSCRIPTION_NAME"
	
	echo -n "Deseja consultar uma nova/outra SKU? (S/N).: "
	read -r resposta
	
	case "$resposta" in 
	[Ss]|[Ss][Ii][Mm]|[Yy]|[Yy]|[Ee][Ss])
	    echo 
		continue
		;;
	*)
	
	    echo "Finalizando..."
		break
		;;
	esac
done