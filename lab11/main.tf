terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.8.0"
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "rg" {
  name     = "az104-rg11"
  location = "East US"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "az104-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet0"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/26"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "az104-nsg01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-rdp"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "pip" {
  name                = "az104-pip0"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  name                = "az104-nic0"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_storage_account" "st" {
  name                     = "az10411${substr(md5(azurerm_resource_group.rg.name), 0, 8)}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                = "az104-vm0"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2s_v3"
  admin_username      = "localadmin"
  admin_password      = "Azureuser123456789&"

  network_interface_ids = [azurerm_network_interface.nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.st.primary_blob_endpoint
  }
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "az104-law11"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_virtual_machine_extension" "monitor_agent" {
  name                 = "AzureMonitorWindowsAgent"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.Monitor"
  type                 = "AzureMonitorWindowsAgent"
  type_handler_version = "1.10"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled = true
}

resource "azurerm_monitor_data_collection_rule" "dcr" {
  name                = "az104-dcr11"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  destinations {
    log_analytics {
      name                  = "to-law"
      workspace_resource_id = azurerm_log_analytics_workspace.law.id
    }
  }

  data_flow {
    streams      = ["Microsoft-InsightsMetrics"]
    destinations = ["to-law"]
  }

  data_sources {
    performance_counter {
      name                = "perf"
      streams             = ["Microsoft-InsightsMetrics"]
      counter_specifiers  = ["\\Processor(_Total)\\% Processor Time", "\\Memory\\Available Bytes", "\\LogicalDisk(_Total)\\% Free Space"]
      sampling_frequency_in_seconds = 60
    }
  }

  depends_on = [azurerm_windows_virtual_machine.vm]
}

resource "azurerm_monitor_data_collection_rule_association" "vm_assoc" {
  name                    = "az104-dcra11"
  target_resource_id      = azurerm_windows_virtual_machine.vm.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr.id
}

resource "azurerm_monitor_action_group" "alert_ops_team" {
  name                = "AlertOpsTeam"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "OpsTeam"

  email_receiver {
    name          = "VMDeletedEmail"
    email_address = var.owner_email
  }
}

resource "azurerm_monitor_activity_log_alert" "vm_delete_alert" {
  name                = "VMWasDeleted"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "global"
  scopes              = [azurerm_resource_group.rg.id]
  description         = "A VM in your resource group was deleted"

  criteria {
    category       = "Administrative"
    resource_type  = "Microsoft.Compute/virtualMachines"
    operation_name = "Microsoft.Compute/virtualMachines/delete"
    status         = "Succeeded"
  }

  action {
    action_group_id = azurerm_monitor_action_group.alert_ops_team.id
  }

  enabled = true
}



