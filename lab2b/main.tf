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

resource "azurerm_resource_group" "rg2" {
  name     = "az104-rg2"
  location = "East US"

  tags = {
    "Cost Center" = "000"
  }
}

output "resource_group_id" {
  value = azurerm_resource_group.rg2.id
}

output "resource_group_tags" {
  value = azurerm_resource_group.rg2.tags
}

data "azurerm_policy_definition" "require_tag" {
  display_name = "Require a tag and its value on resources"
}

resource "azurerm_resource_group_policy_assignment" "require_cost_center_tag" {
  name                 = "Require Cost Center tag and its value on resources"
  display_name         = "Require Cost Center tag and its value on resources"
  resource_group_id    = azurerm_resource_group.rg2.id
  policy_definition_id = data.azurerm_policy_definition.require_tag.id
  description          = "Require Cost Center tag and its value on all resources in the resource group"

  parameters = jsonencode({
    tagName = {
      value = "Cost Center"
    }
    tagValue = {
      value = "000"
    }
  })
}


data "azurerm_policy_definition" "inherit_tag" {
  display_name = "Inherit a tag from the resource group if missing"
}

resource "azurerm_resource_group_policy_assignment" "inherit_cost_center_tag" {
  name                 = "Inherit Cost Center tag and its value 000 from RG if missing"
  display_name         = "Inherit the Cost Center tag and its value 000 from the resource group if missing"
  resource_group_id    = azurerm_resource_group.rg2.id
  policy_definition_id = data.azurerm_policy_definition.inherit_tag.id
  description          = "Automatically inherit Cost Center tag from resource group"

  location = azurerm_resource_group.rg2.location

  parameters = jsonencode({
    tagName = {
      value = "Cost Center"
    }
  })

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_management_lock" "rg_lock" {
  name       = "rg-lock"
  scope      = azurerm_resource_group.rg2.id
  lock_level = "CanNotDelete"
  notes      = "Prevents accidental deletion of the resource group"
}
