# --- Variables ---
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
RG_NAME="scp-rg"             # resource group scope for least privilege
SP_NAME="http://tfc-jenkins-sp"
LOCATION="eastus"                  # Azure region for the resource group (change if needed)

echo "Using Subscription ID: $SUBSCRIPTION_ID"
echo "Targeting Resource Group: $RG_NAME in Location: $LOCATION"

# --- Create Resource Group if it doesn't exist ---
# This command is safe to run multiple times. 
# It will create the RG if missing or do nothing if it already exists.
az group create --name $RG_NAME --location $LOCATION

# --- Create Service Principal with contributor on the resource group (least privilege) ---
# The --sdk-auth flag is deprecated but still used for Terraform compatibility.
echo "Creating Service Principal and assigning 'Contributor' role..."

az ad sp create-for-rbac \
  --name $SP_NAME \
  --role "Contributor" \
  --scopes "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}" \
  --sdk-auth > tfc-sp.json

# --- Display the generated credentials file ---
echo "Service Principal created and credentials saved to tfc-sp.json"
echo "------------------- tfc-sp.json -------------------"
cat tfc-sp.json
echo "-----------------------------------------------------"
