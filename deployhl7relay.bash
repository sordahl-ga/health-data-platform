#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

#Deploy HL7Relay Service to ACI  Author Steve Ordahl MSHLS CSA

declare resourceGroupName=""
declare functionurl=""
declare functionkey=""
declare hl7relay="hl7relay"
declare hl7relayports="8079"
declare hl7relayimage="stodocker/hl7overhttp-relay"
declare vnetsuffix="vnet"
declare subnetname="aci-subnet"
usage() { echo "Usage: $0 <Resource Group Name><HL7FunctionAppURL> <HL7FunctionAppKey>" 1>&2; exit 1; }

if [ "$#" -ne 3 ]; then
    usage
fi
resourceGroupName=$1
functionurl=$2
functionkey=$3

#Start deploy
echo "Starting Health Data Platform Deploy of HL7Relay to "$resourceGroupName
(
	set -x
		#Create HL7 Relay
		echo "Deploying HL7 Relay..."
		az container create --resource-group $resourceGroupName --name $resourceGroupName$hl7relay --image $hl7relayimage --ports $hl7relayports --vnet $resourceGroupName$vnetsuffix --subnet $subnetname --ip-address private --environment-variables HL7OVERHTTPHEADERS=x-functions-key=$functionkey HL7OVERHTTPDEST=$functionurl
)

if [ $?  == 0 ];
 then
	echo $resourceGroupName " Health Data Platform Deploy of HL7Relay succeeded"
fi
