# Ensure you are logged in to Azure with Connect-AzAccount
# Make sure the Az.Resources module is installed (Install-Module Az.Resources)

# --- Variables ---
# Retrieve the current subscription ID dynamically
$SUBSCRIPTION_ID = (Get-AzContext).Subscription.Id
$RG_NAME = "portfolio-rg"             # resource group scope for least privilege
$SP_NAME = "tfc-jenkins-sp"           # Display name for the Service Principal

# Define the full scope path
$Scope = "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME"
$Role = "Contributor"

# --- Create Service Principal and Assign Role ---

Write-Host "Creating Service Principal: $SP_NAME with Role: $Role at Scope: $Scope"

# 1. Create the Azure AD Application
# Note: In PowerShell, we separate application creation from role assignment.
$app = New-AzADApplication -DisplayName $SP_NAME -IdentifierUris "http://$SP_NAME"

# 2. Create the Service Principal associated with the App
$sp = New-AzADServicePrincipal -AppId $app.AppId

# 3. Assign the RBAC role at the specified scope
# This step might take a moment to propagate in Azure AD
New-AzRoleAssignment -ObjectId $sp.ObjectId -RoleDefinitionName $Role -Scope $Scope

Write-Host "Service Principal created successfully. Generating JSON output."

# 4. Generate the output in the specific "sdk-auth" format required by Terraform/SDKs
# The client secret must be generated separately for the New-AzADServicePrincipal command
# The az ad sp create-for-rbac command generates the secret and provides it in the output immediately.
# In PowerShell, we need a slightly different approach as New-AzADServicePrincipal doesn't return the secret directly after creation.
# The Az CLI command is specifically optimized for this workflow.

# If you MUST use PowerShell and MUST have the secret in the output immediately like the CLI command, 
# it is easier to simply run the specific Azure CLI command *within* PowerShell:

az ad sp create-for-rbac --name "http://$SP_NAME" --role "Contributor" --scopes $Scope --sdk-auth | Out-File -FilePath tfc-sp.json -Encoding UTF8

# Display the content of the generated file
Get-Content -Path tfc-sp.json
