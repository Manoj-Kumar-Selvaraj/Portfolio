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
