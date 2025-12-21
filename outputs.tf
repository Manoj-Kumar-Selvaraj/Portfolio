output "resource_group" {
  value = azurerm_resource_group.rg.name
}

output "vm_name" {
  value = azurerm_linux_virtual_machine.jenkins.name
}

output "vm_public_ip" {
  value = azurerm_public_ip.pip.ip_address
}

output "key_vault_name" {
  value = azurerm_key_vault.kv.name
}

############################################
# Outputs for GitHub Actions
############################################
output "github_client_id" {
  value = azuread_application.github_oidc.client_id
}

output "github_tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "github_subscription_id" {
  value = data.azurerm_client_config.current.subscription_id
}
