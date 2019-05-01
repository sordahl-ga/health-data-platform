#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

#Health Data Platform Ingest Destroy--- Author Steve Ordahl MSHLS CSA

declare vnetsuffix="vnet"
declare RES_GROUP=$1
declare deployprefix=""
declare VNET_NAME=$RES_GROUP$vnetsuffix
declare SUBNET_NAME="aci-subnet"
declare ctakes="ctakes"
declare tika="tika"
declare hl7relay="hl7relay"

deployprefix=${RES_GROUP:0:14}
deployprefix=${deployprefix//[^[:alnum:]]/}
deployprefix=${deployprefix,,}

VNET_NAME=$deployprefix$vnetsuffix

NETWORK_PROFILE_SEARCH="$VNET_NAME-$SUBNET_NAME"

NETWORK_PROFILE_ID=$(az network profile list --resource-group $RES_GROUP --query [].id --output tsv | grep -i $NETWORK_PROFILE_SEARCH)

#Start delete
echo "Starting Health Data Platform Ingest delete of group "$RES_GROUP
(
	set -x
	az container delete -g $RES_GROUP --name $RES_GROUP$ctakes -y
	az container delete -g $RES_GROUP --name $RES_GROUP$tika -y
	az container delete -g $RES_GROUP --name $RES_GROUP$hl7relay -y
	echo "Allowing containers to fully desolve..."
	sleep 20
	az network profile delete --ids $NETWORK_PROFILE_ID -y
	SAL_ID=$(az network vnet subnet show --resource-group $RES_GROUP --vnet-name $VNET_NAME --name $SUBNET_NAME --query id --output tsv)/providers/Microsoft.ContainerInstance/serviceAssociationLinks/default
	az resource delete --ids $SAL_ID --api-version 2018-07-01
	az network vnet subnet update --resource-group $RES_GROUP --vnet-name $VNET_NAME --name $SUBNET_NAME --remove delegations 0
	#az network vnet delete --resource-group $RES_GROUP --name $VNET_NAME
	az group delete -n $RES_GROUP
)

if [ $?  == 0 ];
 then
	echo $RES_GROUP " Health Data Platform Ingest has successfully been deleted"
fi
