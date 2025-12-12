locals {
  prefix = var.prefix
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "${local.prefix}-rg"
  location = var.location
  tags     = local.common_tags 
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${local.prefix}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
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
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "22"
  }

  security_rule {
    name                       = "Allow-Jenkins"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "Internet"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "8080"
  }
}

resource "azurerm_public_ip" "pip" {
  name                = "${local.prefix}-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
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
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Read public SSH key
data "local_file" "ssh_pub" {
  filename = replace(var.ssh_public_key_path, "~", pathexpand("~"))
}

resource "azurerm_linux_virtual_machine" "jenkins" {
  name                = var.vm_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = data.local_file.ssh_pub.content
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

  # pass cloud-init as custom_data (templatefile will render values)
  custom_data = base64encode(templatefile("${path.module}/cloud-init.sh", {
    key_vault_name       = var.key_vault_name != "" ? var.key_vault_name : "${local.prefix}-kv"
    resource_group_name  = azurerm_resource_group.rg.name
    vm_name              = var.vm_name
  }))
}

# Create Key Vault
resource "azurerm_key_vault" "kv" {
  name                        = var.key_vault_name != "" ? var.key_vault_name : "${local.prefix}-kv"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  enable_purge_protection     = false
  enable_soft_delete          = true

  # initial access policy: give the VM managed identity get/list
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_linux_virtual_machine.jenkins.identity[0].principal_id

    secret_permissions = [
      "get",
      "list"
    ]
  }

  # Also allow current principal so you can set secrets with az cli from your account
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    secret_permissions = ["get","list","set","delete"]
  }
}

# A placeholder secret (you will overwrite or update after creating Jenkins)
resource "azurerm_key_vault_secret" "jenkins_token" {
  name         = "jenkins-apitoken"
  value        = "PLACEHOLDER_REPLACE_AFTER_JENKINS_SETUP"
  key_vault_id = azurerm_key_vault.kv.id
}

# Optional: tag everything
locals {
  common_tags = {
    Owner = "manoj"
    Project = "jenkins-on-demand"
  }
}
