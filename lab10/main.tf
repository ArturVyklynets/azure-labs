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
  name     = "az104-rg-region1"
  location = "East US"
}

resource "azurerm_recovery_services_vault" "rsv" {
  name                = "az104-rsv-region1"
  location            = "East US"
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  storage_mode_type = "GeoRedundant"

  soft_delete_enabled = true
}

resource "azurerm_backup_policy_vm" "policy" {
  name                = "az104-backup"
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.rsv.name

  backup {
    frequency = "Daily"
    time      = "00:00"
  }

  retention_daily {
    count = 7
  }
  
  timezone = "UTC"
}

data "azurerm_virtual_machine" "vm" {
  name                = "az104-10-vm0"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_backup_protected_vm" "vm_backup" {
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.rsv.name
  source_vm_id        = data.azurerm_virtual_machine.vm.id
  backup_policy_id    = azurerm_backup_policy_vm.policy.id
}

resource "azurerm_storage_account" "logs" {
  name                     = "az104rsvlogslabvyklynets"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_monitor_diagnostic_setting" "rsv_diagnostics" {
  name               = "Logs and Metrics to storage"
  target_resource_id = azurerm_recovery_services_vault.rsv.id
  storage_account_id = azurerm_storage_account.logs.id

  enabled_log {
    category = "AzureBackupReport"
  }
  
  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_resource_group" "rg_region2" {
  name     = "az104-rg-region2"
  location = "West US"
}

resource "azurerm_recovery_services_vault" "rsv_region2" {
  name                = "az104-rsv-region2"
  location            = azurerm_resource_group.rg_region2.location
  resource_group_name = azurerm_resource_group.rg_region2.name
  sku                 = "Standard"
  soft_delete_enabled = true
  storage_mode_type   = "GeoRedundant"
}