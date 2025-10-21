output "management_group_id" {
  description = "ID створеної Management Group"
  value       = azurerm_management_group.az104_mg1.id
}

output "management_group_name" {
  description = "Назва Management Group"
  value       = azurerm_management_group.az104_mg1.display_name
}
