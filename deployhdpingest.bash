#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)
#Health Data Platform Ingest Setup --- Author Steve Ordahl MSHLS CSA

usage() { echo "Usage: $0 -i <subscriptionId> -g <resourceGroupName> -l <resourceGroupLocation> -p <prefix>" 1>&2; exit 1; }

declare defsubscriptionId=""
declare subscriptionId=""
declare resourceGroupName=""
declare resourceGroupLocation=""
declare vnetipprefix="10.0.0.0/16"
declare subnetprefix="10.0.0.0/24"
declare vnetsuffix="vnet"
declare subnetname="aci-subnet"
declare storageAccountNameSuffix="store"$RANDOM
declare storageConnectionString=""
declare searchSuffix="search"
declare searchKey=""
declare serviceplanSuffix="asp"
declare faname=HDPTransform$RANDOM
declare ctakes="ctakes"
declare ctakesip=""
declare ctakesimage="stodocker/ctakes-healthnlp"
declare ctakesports="8080"
declare tika="tika"
declare tikaimage="stodocker/tikaserver"
declare tikaports="9998"
declare tikaip=""
declare dbaccountNameSuffix="db"
declare dbdatabaseName="hdp"
declare dbcollectionName="messages"
declare dbccdcollectionName="ccds"
declare dbthruput="400"
declare dbkey=""
declare dbendpoint="";
declare repoURL="https://github.com/sordahl-ga/TransformFunctions"
declare repoBranch="hdporigin"
declare deployprefix=""
declare defdeployprefix=""
declare storecontainername="hl7json"
# Initialize parameters specified from command line
while getopts ":i:g:n:l:p" arg; do
	case "${arg}" in
		p)
			deployprefix=${OPTARG:0:14}
			deployprefix=${deployprefix,,}
			deployprefix=${deployprefix//[^[:alnum:]]/}
			;;
		i)
			subscriptionId=${OPTARG}
			;;
		g)
			resourceGroupName=${OPTARG}
			;;
		l)
			resourceGroupLocation=${OPTARG}
			;;
		esac
done
shift $((OPTIND-1))
#login to azure using your credentials
az account show 1> /dev/null

if [ $? != 0 ];
then
	az login
fi

defsubscriptionId=$(az account show --query "id" --out json | sed 's/"//g') 

#Prompt for parameters is some required parameters are missing
if [[ -z "$subscriptionId" ]]; then
	echo "Enter your subscription ID ["$defsubscriptionId"]:"
	read subscriptionId
	if [ -z "$subscriptionId" ] ; then
		subscriptionId=$defsubscriptionId
	fi
	[[ "${subscriptionId:?}" ]]
fi

if [[ -z "$resourceGroupName" ]]; then
	echo "This script will look for an existing resource group, otherwise a new one will be created "
	echo "You can create new resource groups with the CLI using: az group create "
	echo "Enter a resource group name"
	read resourceGroupName
	[[ "${resourceGroupName:?}" ]]
fi

defdeployprefix=${resourceGroupName:0:14}
defdeployprefix=${defdeployprefix//[^[:alnum:]]/}
defdeployprefix=${defdeployprefix,,}

if [[ -z "$resourceGroupLocation" ]]; then
	echo "If creating a *new* resource group, you need to set a location "
	echo "You can lookup locations with the CLI using: az account list-locations "
	
	echo "Enter resource group location:"
	read resourceGroupLocation
fi
#Prompt for parameters is some required parameters are missing
if [[ -z "$deployprefix" ]]; then
	echo "Enter your deployment prefix ["$defdeployprefix"]:"
	read deployprefix
	if [ -z "$deployprefix" ] ; then
		deployprefix=$defdeployprefix
	fi
	deployprefix=${deployprefix:0:14}
	deployprefix=${deployprefix//[^[:alnum:]]/}
    deployprefix=${deployprefix,,}
	[[ "${deployprefix:?}" ]]
fi
if [ -z "$subscriptionId" ] || [ -z "$resourceGroupName" ]; then
	echo "Either one of subscriptionId, resourceGroupName is empty"
	usage
fi

#login to azure using your credentials
az account show 1> /dev/null

if [ $? != 0 ];
then
	az login
fi

#set the default subscription id
az account set --subscription $subscriptionId

set +e

#Check for existing RG
az group show --name $resourceGroupName 1> /dev/null

if [ $? != 0 ]; then
	echo "Resource group with name" $resourceGroupName "could not be found. Creating new resource group.."
	set -e
	(
		set -x
		az group create --name $resourceGroupName --location $resourceGroupLocation 1> /dev/null
	)
	else
	echo "Using existing resource group..."
fi
#Start deployment
echo "Starting Health Data Platform Ingest deployment..."
(
	set -x
	    #Create comosdb for HL7 Transform Storage and Analysis
		echo "Creating CosmosDB(SQLAPI) Account for HL7 Message Transform Storage...."
		dbendpoint=$(az cosmosdb create --resource-group $resourceGroupName --name $deployprefix$dbaccountNameSuffix --kind GlobalDocumentDB --locations $resourceGroupLocation=0 --default-consistency-level "Session" --query "documentEndpoint" --out json | sed 's/"//g')
		#Create database for ingestion
		echo "Creating ingest DB on CosmosDB Account..."
		temp=$(az cosmosdb database create --resource-group $resourceGroupName --name $deployprefix$dbaccountNameSuffix --db-name $dbdatabaseName)
		#Create the containing collection
		echo "Creating hl7 Collection on ingest DB..."
		temp=$(az cosmosdb collection create --resource-group $resourceGroupName --collection-name $dbcollectionName --name $deployprefix$dbaccountNameSuffix --db-name $dbdatabaseName --partition-key-path /id --throughput $dbthruput)
		echo "Creating ccd Collection on ingest DB..."
		temp=$(az cosmosdb collection create --resource-group $resourceGroupName --collection-name $dbccdcollectionName --name $deployprefix$dbaccountNameSuffix --db-name $dbdatabaseName --partition-key-path /id --throughput $dbthruput)
		echo "Getting Access Key to Account..."
		dbkey=$(az cosmosdb list-keys --name $deployprefix$dbaccountNameSuffix --resource-group $resourceGroupName --query "primaryMasterKey" --out json | sed 's/"//g')
		#Create Storage Account
		echo "Creating Storage Account and Ingest container..."
		az storage account create --name $deployprefix$storageAccountNameSuffix --resource-group $resourceGroupName --location  $resourceGroupLocation --sku Standard_LRS --encryption blob
		storageConnectionString=$(az storage account show-connection-string -g $resourceGroupName -n $deployprefix$storageAccountNameSuffix --query "connectionString" --out json | sed 's/"//g')
		az storage container create -n $storecontainername --connection-string $storageConnectionString
		echo "Creating Azure Search Instance..."
		az search service create -n $deployprefix$searchSuffix -g $resourceGroupName --sku basic -l $resourceGroupLocation
		searchKey=$(az search admin-key show --resource-group=$resourceGroupName --service-name=$deployprefix$searchSuffix  --query "primaryKey" --out json | sed 's/"//g')
		#Create CTAKES Container on VNET Internal IP expose ports
		echo "Creating VNET and Deploying CTAKES..."
		az container create --resource-group $resourceGroupName --name $deployprefix$ctakes --image $ctakesimage --ports $ctakesports --vnet $deployprefix$vnetsuffix --vnet-address-prefix $vnetipprefix --subnet $subnetname --subnet-address-prefix $subnetprefix --ip-address private
		ctakesip=$(az container show --name  $deployprefix$ctakes --resource-group $resourceGroupName  --query "ipAddress.ip" --out json | sed 's/"//g') 
		echo "CTakes IP Address "$ctakesip
		#Create TIKAServer Container on VNET Internal IP expose ports
		echo "Deploying TIKAServer..."
		az container create --resource-group $resourceGroupName --name $deployprefix$tika --image $tikaimage --ports $tikaports --vnet $deployprefix$vnetsuffix --subnet $subnetname --ip-address private
		tikaip=$(az container show --name  $deployprefix$tika --resource-group $resourceGroupName  --query "ipAddress.ip" --out json | sed 's/"//g')
		echo "Tika IP Address "$tikaip
		#Create Transform Functions App
		#Create Service Plan
		echo "Deploying Transform Function App..."
		az appservice plan create -g  $resourceGroupName -n $deployprefix$serviceplanSuffix --number-of-workers 2 --sku P1v2
		#Create the Transform Function App
		az functionapp create --name $faname --storage-account $deployprefix$storageAccountNameSuffix  --plan $deployprefix$serviceplanSuffix  --resource-group $resourceGroupName --runtime dotnet --os-type Windows
		#Add App Settings
		#CosmosDB
		az functionapp config appsettings set --name $faname  --resource-group $resourceGroupName --settings CosmosDBConnection="AccountEndpoint="$dbendpoint";AccountKey="$dbkey
		az functionapp config appsettings set --name $faname  --resource-group $resourceGroupName --settings CosmosDBNAME=$dbdatabaseName
		az functionapp config appsettings set --name $faname  --resource-group $resourceGroupName --settings CosmosCCDCollection=$dbccdcollectionName
		az functionapp config appsettings set --name $faname  --resource-group $resourceGroupName --settings CosmosHL7Collection=$dbcollectionName
		#StorageAccount
		az functionapp config appsettings set --name $faname  --resource-group $resourceGroupName --settings StorageAccount=$storageConnectionString StorageAccountBlob=$storecontainername
		#search service
	    az functionapp config appsettings set --name $faname  --resource-group $resourceGroupName --settings SearchServiceKey=$searchKey SearchServiceName=$deployprefix$searchSuffix SearchServiceIndexName=medical-documents
		#CTAKES
		az functionapp config appsettings set --name $faname  --resource-group $resourceGroupName --settings CTAKESFormat=XML CTAKESUMLSUser=${HDPUMLSUSER:-<user>} CTAKESUMLSPassword=${HDPUMLSPASSWORD:-<pass>} CTAKESServerURL=http://$ctakesip:$ctakesports/DemoServlet
		#TIKAServer
		az functionapp config appsettings set --name $faname  --resource-group $resourceGroupName --settings TIKAServerurl=http://$tikaip:$tikaports/tika
		#Deployment from GIT
		az functionapp deployment source config --name $faname --resource-group $resourceGroupName --branch $repoBranch --repo-url $repoURL --manual-integration
	
		)


	
if [ $?  == 0 ];
 then
	echo "Health Data Platform Ingest has successfully been deployed"
fi
