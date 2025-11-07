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

data "http" "my_ip" {
  url = "https://api.ipify.org"
}

resource "azurerm_resource_group" "rg" {
  name     = "az104-rg7"
  location = "East US"
}

resource "azurerm_storage_account" "storage" {
  name                     = "az104storagelabvyklynnnm"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  public_network_access_enabled = true
  allow_nested_items_to_be_public = false

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "azurerm_storage_account_network_rules" "rules" {
  storage_account_id = azurerm_storage_account.storage.id
  default_action      = "Deny"

  virtual_network_subnet_ids = [
    azurerm_subnet.default.id
  ]

  bypass = ["AzureServices"]
}

resource "azurerm_storage_management_policy" "policy" {
  storage_account_id = azurerm_storage_account.storage.id

  rule {
    name    = "Movetocool"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 30
      }
    }
  }
}

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_id  = azurerm_storage_account.storage.id
  container_access_type = "private"
}

resource "azurerm_storage_container_immutability_policy" "retention" {
  storage_container_resource_manager_id = azurerm_storage_container.data.id
  immutability_period_in_days           = 180
  protected_append_writes_all_enabled   = false
}

resource "azurerm_storage_share" "share1" {
  name                 = "share1"
  storage_account_name = azurerm_storage_account.storage.name
  quota                = 50
  access_tier          = "TransactionOptimized"
}

resource "azurerm_storage_share_file" "uploaded_file" {
  name             = "sample.txt"
  storage_share_id = azurerm_storage_share.share1.id
  source           = "./07/sample.txt"
}
resource "azurerm_virtual_network" "vnet1" {
  name                = "vnet1"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "default" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.10.1.0/24"]

  service_endpoints = ["Microsoft.Storage"]
}
