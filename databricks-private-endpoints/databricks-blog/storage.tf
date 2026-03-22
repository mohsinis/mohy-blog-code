# Data source to lookup the AD group
data "azuread_group" "contoso_cloud_admins" {
  display_name     = "contoso-cloud-admins"
  security_enabled = true
}

resource "azurerm_storage_account" "stg1" {
  name                            = local.storage_account_stg1_name
  resource_group_name             = local.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  is_hns_enabled                  = true
  network_rules {
    default_action = "Deny"
  }
  depends_on = [azurerm_resource_group.main]
  tags       = local.common_tags
}

resource "azurerm_storage_account" "stg2" {
  name                            = local.storage_account_stg2_name
  resource_group_name             = local.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  is_hns_enabled                  = true
  network_rules {
    default_action = "Deny"
  }
  depends_on = [azurerm_resource_group.main]
  tags       = local.common_tags
}

# Blob containers for contoso<env>ccdbwucstg001
resource "azurerm_storage_container" "test_catalog" {
  name                  = local.container_test_catalog_name
  storage_account_id    = azurerm_storage_account.stg2.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "risk_resolution_catalog" {
  name                  = local.container_risk_resolution_catalog_name
  storage_account_id    = azurerm_storage_account.stg2.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "unitycatalog" {
  name                  = local.container_unitycatalog_name
  storage_account_id    = azurerm_storage_account.stg2.id
  container_access_type = "private"
}

# Blob containers for contoso<env>ccdbwingstg001
resource "azurerm_storage_container" "test" {
  name                  = local.container_test_name
  storage_account_id    = azurerm_storage_account.stg1.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "raw" {
  name                  = local.container_raw_name
  storage_account_id    = azurerm_storage_account.stg1.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "risk_resolution" {
  name                  = local.container_risk_resolution_name
  storage_account_id    = azurerm_storage_account.stg1.id
  container_access_type = "private"
}

# IAM for Databricks Access Connectors on Storage Accounts
resource "azurerm_role_assignment" "ings_blob" {
  scope                = azurerm_storage_account.stg1.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.ings.identity[0].principal_id
}

resource "azurerm_role_assignment" "ings_queue" {
  scope                = azurerm_storage_account.stg1.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_databricks_access_connector.ings.identity[0].principal_id
}

resource "azurerm_role_assignment" "unity_blob" {
  scope                = azurerm_storage_account.stg2.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.unity_catalog.identity[0].principal_id
}

resource "azurerm_role_assignment" "unity_queue" {
  scope                = azurerm_storage_account.stg2.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_databricks_access_connector.unity_catalog.identity[0].principal_id
}

# IAM for contoso-cloud-admins AD group on Storage Accounts
resource "azurerm_role_assignment" "cloud_admins_stg1" {
  scope                = azurerm_storage_account.stg1.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_group.contoso_cloud_admins.object_id
}

resource "azurerm_role_assignment" "cloud_admins_stg2" {
  scope                = azurerm_storage_account.stg2.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_group.contoso_cloud_admins.object_id
} 