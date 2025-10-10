resource "azuread_user" "az104_user1" {
  user_principal_name = "az104-user1@${var.domain_name}"
  display_name        = "az104-user1"
  mail_nickname       = "az104-user1"
  account_enabled     = true
  password            = random_password.user_password.result
  job_title           = "IT Lab Administrator"
  department          = "IT"
  usage_location      = "US"
}

resource "random_password" "user_password" {
  length  = 12
  special = true
}

resource "azuread_invitation" "external_user" {
  user_display_name  = "ArtuPNUAcc"
  user_email_address = "artur.vyklynets.22@pnu.edu.ua"
  redirect_url       = "https://portal.azure.com"

  message {
    body = "Welcome to Azure and our group project"
  }
}

