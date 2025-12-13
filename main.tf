############################################
# Locals
############################################

locals {
  prefix = var.prefix

  # Render cloud-init with substituted variables
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
# Client config
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
# KEY VAULT
############################################

resource "azurerm_key_vault" "kv" {
  name                        = var.key_vault_name != "" ? var.key_vault_name : "${local.prefix}-kv"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"

  tags = local.common_tags
}

############################################
# Initial secret placeholder
############################################

resource "azurerm_key_vault_secret" "jenkins_token" {
  name         = var.vault_secret_name
  value        = "PLACEHOLDER_REPLACE_AFTER_JENKINS_SETUP"
  key_vault_id = azurerm_key_vault.kv.id
}

############################################
# VM cloud-init trigger (Hash-based)
############################################

resource "null_resource" "cloudinit_hash" {
  triggers = {
    content_sha = sha256(local.cloudinit_content)
  }
}

############################################
# VM instance
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

  # cloud-init (base64 encoded)
  custom_data = base64encode(local.cloudinit_content)

  lifecycle {
    replace_triggered_by = [
      null_resource.cloudinit_hash
    ]
  }

  tags = local.common_tags
}

############################################
# Grant VM managed identity access to Key Vault AFTER VM creation
############################################

resource "azurerm_key_vault_access_policy" "vm_kv_man_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_virtual_machine.jenkins.identity[0].principal_id

  secret_permissions = ["Get", "List"]
}
