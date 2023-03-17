#!/bin/bash
LOCATION="westeurope"
PROJECT="dabfsight"
RESOURCE_GROUP="rg-${PROJECT}"
LOCATION="westeurope"
DAB_CONFIG_FILE="../dab-config.json"

# ********************************************
# *****Infra
# ********************************************
LOG_ANALYTICS_WORKSPACE="lga-${PROJECT}"
REGISTRY="${PROJECT}"

echo "... Create resource group [$RESOURCE_GROUP]"
az group create -l $LOCATION -n $RESOURCE_GROUP

echo "... Create log analytics workspace [$LOG_ANALYTICS_WORKSPACE]"
az monitor log-analytics workspace create \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --workspace-name "$LOG_ANALYTICS_WORKSPACE"

echo "... Retrieving log analytics client id"
LOG_ANALYTICS_WORKSPACE_CLIENT_ID=`az monitor log-analytics workspace show  \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$LOG_ANALYTICS_WORKSPACE" \
  --query customerId  \
  --output tsv | tr -d '[:space:]'`

echo $LOG_ANALYTICS_WORKSPACE_CLIENT_ID

echo "... Retrieving log analytics secret"
LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET=`az monitor log-analytics workspace get-shared-keys \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$LOG_ANALYTICS_WORKSPACE" \
  --query primarySharedKey \
  --output tsv | tr -d '[:space:]'`

echo $LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET

echo "... Creating Azure Container Registry [$REGISTRY]"
az acr create \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --name "$REGISTRY" \
  --workspace "$LOG_ANALYTICS_WORKSPACE" \
  --sku Standard \
  --admin-enabled true

echo "... Allowing anonymous pull to Container Registry"
az acr update \
  --resource-group "$RESOURCE_GROUP" \
  --name "$REGISTRY" \
  --anonymous-pull-enabled true

echo "... Retrieving Container Registry URL"
REGISTRY_URL=$(az acr show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$REGISTRY" \
  --query "loginServer" \
  --output tsv)

echo $REGISTRY_URL

# ********************************************
# *****Storage account
# ******************************************** 
STORAGE_ACCOUNT="${PROJECT}"
echo "... Creating storage account [$STORAGE_ACCOUNT]" 

az storage account create --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS

echo "... Retrieving storage connection string"
STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name $STORAGE_ACCOUNT -g $RESOURCE_GROUP -o tsv)

echo "... Creating file share"
az storage share create -n dabconfig --connection-string $STORAGE_CONNECTION_STRING

echo "... Uploading DAB configuration file [$DAB_CONFIG_FILE]" 
az storage file upload --source $DAB_CONFIG_FILE --path "dab-config.json" --share-name "dabconfig" \
  --connection-string $STORAGE_CONNECTION_STRING

echo "... Retrieving storage key" 
STORAGE_KEY=$(az storage account keys list -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT --query '[0].value' -o tsv) 

# ********************************************
# *****Container Apps
# ********************************************
CONTAINERAPPS_ENVIRONMENT="env-${PROJECT}"
IMAGES_TAG="1.0.0"
APP_NAME="${PROJECT}-customers"
#APP_IMAGE="${REGISTRY_URL}/${APP_NAME}:${IMAGES_TAG}"
APP_IMAGE="mcr.microsoft.com/azure-databases/data-api-builder:latest"

echo "... Creating Azure Container Apps environment [$CONTAINERAPPS_ENVIRONMENT] "
az containerapp env create \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --name "$CONTAINERAPPS_ENVIRONMENT" \
  --logs-workspace-id "$LOG_ANALYTICS_WORKSPACE_CLIENT_ID" \
  --logs-workspace-key "$LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET"


echo "... Mount storage account [$STORAGE_ACCOUNT]"
az containerapp env storage set --name $CONTAINERAPPS_ENVIRONMENT \
  --resource-group $RESOURCE_GROUP \
  --storage-name $STORAGE_ACCOUNT \
  --azure-file-account-name $STORAGE_ACCOUNT \
  --azure-file-account-key $STORAGE_KEY \
  --azure-file-share-name "dabconfig" \
  --access-mode ReadWrite

echo "... Creating app [$APP_NAME] in Azure Container Apps"
az containerapp create \
  --resource-group $RESOURCE_GROUP \
  --image $APP_IMAGE \
  --name $APP_NAME \
  --environment $CONTAINERAPPS_ENVIRONMENT \
  --ingress external \
  --target-port 5000 \
  --min-replicas 0 \
  --command "dotnet Azure.DataApiBuilder.Service.dll --ConfigFileName /dabconfig/dab-config.json"


ACA_FQDN = az containerapp show -n $APP_NAME -g $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv

echo "... App [$APP_NAME] available at this address [https://$ACA_FQDN]"

echo "... Script completed"