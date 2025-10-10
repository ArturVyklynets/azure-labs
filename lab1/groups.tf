data "azuread_client_config" "current" {}

data "azuread_user" "me" {
  user_principal_name = "artur2005456_gmail.com#EXT#@artur2005456gmail327.onmicrosoft.com"
}

resource "azuread_group" "it_lab_admins" {
  owners           = [data.azuread_user.me.object_id]
  display_name     = "IT Lab Administrators"
  description      = "Administrators that manage the IT lab"
  security_enabled = true
}

resource "azuread_group_member" "az104_user1_member" {
  group_object_id  = azuread_group.it_lab_admins.object_id
  member_object_id = azuread_user.az104_user1.object_id
}


data "azuread_user" "guest_user" {
  user_principal_name = "artur.vyklynets.22_pnu.edu.ua#EXT#@${var.domain_name}"
}

resource "azuread_group_member" "external_user_member" {
  group_object_id  = azuread_group.it_lab_admins.object_id
  member_object_id = data.azuread_user.guest_user.object_id
}
