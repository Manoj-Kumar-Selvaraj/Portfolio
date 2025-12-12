# Variables
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
RG_NAME="portfolio-rg"             # resource group scope for least privilege
SP_NAME="http://tfc-jenkins-sp"

# Create Service Principal with contributor on the resource group (least privilege)
az ad sp create-for-rbac \
  --name $SP_NAME \
  --role "Contributor" \
  --scopes "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}" \
  --sdk-auth > tfc-sp.json

# tfc-sp.json contains fields used by Terraform CLI (but for TFC we will use individual vars)
cat tfc-sp.json
