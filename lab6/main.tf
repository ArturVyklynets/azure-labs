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
  name     = "az104-rg6"
  location = "East US"
}

data "azurerm_network_interface" "nic0" {
  name                = "az104-06-nic0"
  resource_group_name = azurerm_resource_group.rg.name
}

data "azurerm_network_interface" "nic1" {
  name                = "az104-06-nic1"
  resource_group_name = azurerm_resource_group.rg.name
}

data "azurerm_network_interface" "nic2" {
  name                = "az104-06-nic2"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_public_ip" "lb_pip" {
  name                = "az104-lbpip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "lb" {
  name                = "az104-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "az104-fe"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "lb_backend" {
  name            = "az104-be"
  loadbalancer_id = azurerm_lb.lb.id
}

resource "azurerm_lb_probe" "lb_probe" {
  name                = "az104-hp"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "lb_rule" {
  name                           = "az104-lbrule"
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "az104-fe"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_backend.id]
  probe_id                       = azurerm_lb_probe.lb_probe.id
}

resource "azurerm_network_interface_backend_address_pool_association" "vm0_pool" {
  network_interface_id    = data.azurerm_network_interface.nic0.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_backend.id
}

resource "azurerm_network_interface_backend_address_pool_association" "vm1_pool" {
  network_interface_id    = data.azurerm_network_interface.nic1.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_backend.id
}

resource "azurerm_subnet" "subnet_appgw" {
  name                 = "subnet-appgw"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = "az104-06-vnet1"
  address_prefixes     = ["10.60.3.224/27"]
}

resource "azurerm_public_ip" "appgw_pip" {
  name                = "az104-appgwpip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "appgw" {
  name                = "az104-appgw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = azurerm_subnet.subnet_appgw.id
  }

  frontend_port {
    name = "frontendPort"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "appGwFrontendIp"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  backend_address_pool {
    name = "imagePool"
  }

  backend_address_pool {
    name = "videoPool"
  }

  backend_http_settings {
    name                  = "httpSettings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  http_listener {
    name                           = "appGwListener"
    frontend_ip_configuration_name = "appGwFrontendIp"
    frontend_port_name             = "frontendPort"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "rule1"
    rule_type                  = "Basic"
    http_listener_name         = "appGwListener"
    backend_address_pool_name  = "imagePool"
    backend_http_settings_name = "httpSettings"
    priority                   = 100
  }

  tags = {
    environment = "lab"
  }
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "image_assoc" {
  network_interface_id    = data.azurerm_network_interface.nic1.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = one([
    for pool in azurerm_application_gateway.appgw.backend_address_pool : pool.id
    if pool.name == "imagePool"
  ])
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "video_assoc" {
  network_interface_id    = data.azurerm_network_interface.nic2.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = one([
    for pool in azurerm_application_gateway.appgw.backend_address_pool : pool.id
    if pool.name == "videoPool"
  ])
}

