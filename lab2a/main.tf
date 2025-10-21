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

resource "azurerm_management_group" "az104_mg1" {
  name         = "az104-mg1"
  display_name = "az104-mg1"
}

resource "azuread_group" "helpdesk" {
  display_name     = "helpdesk"
  security_enabled = true
}

resource "azurerm_role_assignment" "helpdesk_vm_contributor" {
  scope                = azurerm_management_group.az104_mg1.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azuread_group.helpdesk.object_id
}

resource "azurerm_role_definition" "custom_support_request" {
  name        = "Custom Support Request"
  scope       = azurerm_management_group.az104_mg1.id
  description = "A custom contributor role for support requests."

  permissions {
    actions = [
      "Microsoft.Support/*"
    ]

    not_actions = [
      "Microsoft.Support/register/action"
    ]
  }

  assignable_scopes = [
    azurerm_management_group.az104_mg1.id
  ]
}