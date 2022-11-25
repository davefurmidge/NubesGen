terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.11.0"
    }
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = "1.2.16"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

locals {
  // If an environment is set up (dev, test, prod...), it is used in the application name
  environment = var.environment == "" ? "dev" : var.environment
}

resource "azurecaf_name" "resource_group" {
  name          = var.application_name
  resource_type = "azurerm_resource_group"
  suffixes      = [local.environment]
}

resource "azurerm_resource_group" "main" {
  name     = azurecaf_name.resource_group.result
  location = var.location

  tags = {
    "terraform"        = "true"
    "environment"      = local.environment
    "application-name" = var.application_name
    "nubesgen-version" = "undefined"

    // Name of the Azure Storage Account that stores the Terraform state
    "terraform_storage_account" = var.terraform_storage_account
  }
}

module "application" {
  source           = "./modules/app-service"
  resource_group   = azurerm_resource_group.main.name
  application_name = var.application_name
  environment      = local.environment
  location         = var.location

  azure_application_insights_instrumentation_key = module.application-insights.azure_application_insights_instrumentation_key

  vault_id = module.key-vault.vault_id

  azure_redis_host     = module.redis.azure_redis_host
  azure_redis_password = "@Microsoft.KeyVault(SecretUri=${module.key-vault.vault_uri}secrets/redis-password)"

  azure_storage_account_name  = module.storage-blob.azurerm_storage_account_name
  azure_storage_blob_endpoint = module.storage-blob.azurerm_storage_blob_endpoint
  azure_storage_account_key   = "@Microsoft.KeyVault(SecretUri=${module.key-vault.vault_uri}secrets/storage-account-key)"
}

module "application-insights" {
  source           = "./modules/application-insights"
  resource_group   = azurerm_resource_group.main.name
  application_name = var.application_name
  environment      = local.environment
  location         = var.location
}

module "key-vault" {
  source           = "./modules/key-vault"
  resource_group   = azurerm_resource_group.main.name
  application_name = var.application_name
  environment      = local.environment
  location         = var.location

  redis_password = module.redis.azure_redis_password

  storage_account_key = module.storage-blob.azurerm_storage_account_key
}

module "redis" {
  source           = "./modules/redis"
  resource_group   = azurerm_resource_group.main.name
  application_name = var.application_name
  environment      = local.environment
  location         = var.location
}

module "storage-blob" {
  source           = "./modules/storage-blob"
  resource_group   = azurerm_resource_group.main.name
  application_name = var.application_name
  environment      = local.environment
  location         = var.location
}
