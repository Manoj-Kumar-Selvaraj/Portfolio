############################################
# Locals
############################################

locals {
  prefix = var.prefix

  cloudinit_content = templatefile("${path.module}/cloud-init.sh", {
    key_vault_name      = var.key_vault_name != "" ? var.key_vault_name : "${local.prefix}-kv"
    resource_group_name = "${local.prefix}-rg"
    vm_name             = var.vm_name
    IDLE_MINUTES        = 5
  })

  common_tags = {
    Owner   = "manoj"
    Project = "jenkins-on-demand"
  }
}

############################################
# Client config (Terraform identity)
############################################

data "azurerm_client_config" "current" {}

############################################
# Resource Group
############################################

resource "azurerm_resource_group" "rg" {
  name     = "${local.prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

############################################
# Networking
############################################

resource "azurerm_virtual_network" "vnet" {
  name                = "${local.prefix}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  tags                = local.common_tags
}

resource "azurerm_subnet" "subnet" {
  name                 = "${local.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${local.prefix}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
    source_port_range          = "*"
    destination_port_range     = "22"
  }

  security_rule {
    name                       = "Allow-Jenkins"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
    source_port_range          = "*"
    destination_port_range     = "8080"
  }

  tags = local.common_tags
}

resource "azurerm_public_ip" "pip" {
  name                = "${local.prefix}-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_network_interface" "nic" {
  name                = "${local.prefix}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }

  tags = local.common_tags
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

############################################
# Key Vault (RBAC ONLY – no access policies)
############################################

resource "azurerm_key_vault" "kv" {
  name                        = var.key_vault_name != "" ? var.key_vault_name : "${local.prefix}-kv"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  rbac_authorization_enabled  = true

  tags = local.common_tags
}

############################################
# RBAC — Terraform identity (write secrets)
############################################

resource "azurerm_role_assignment" "tf_kv_secrets_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

############################################
# Cloud-init hash trigger
############################################

resource "null_resource" "cloudinit_hash" {
  triggers = {
    sha = sha256(local.cloudinit_content)
  }
}

############################################
# Jenkins VM
############################################

resource "azurerm_linux_virtual_machine" "jenkins" {
  name                = var.vm_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_pub_key
  }


  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(local.cloudinit_content)

  lifecycle {
    replace_triggered_by = [
      null_resource.cloudinit_hash
    ]
  }

  tags = local.common_tags
}

resource "null_resource" "cloudinit_logs" {
  depends_on = [azurerm_linux_virtual_machine.jenkins]

  connection {
    type        = "ssh"
    user        = var.admin_username
    private_key = var.ssh_pri_key
    host        = azurerm_public_ip.pip.ip_address
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '==== cloud-init status ===='",
      "cloud-init status || true",
      "echo '==== cloud-init-output.log ===='",
      "sudo tail -n 200 /var/log/cloud-init-output.log || true"
    ]
  }
}


############################################
# RBAC — Jenkins VM Managed Identity (read secrets)
############################################

resource "azurerm_role_assignment" "vm_kv_secrets_reader" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.jenkins.identity[0].principal_id
}

############################################
# Jenkins API Token Secret (placeholder)
############################################

resource "azurerm_key_vault_secret" "jenkins_token" {
  name         = var.vault_secret_name
  value        = "PLACEHOLDER_REPLACE_AFTER_JENKINS_SETUP"
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_role_assignment.tf_kv_secrets_officer
  ]
}
