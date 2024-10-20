locals {
  linux_image_id               = local.use_linux_image ? var.azure_linux_os_image_id : (local.use_linux_vhd ? azurerm_image.linux_vhd.0.id : null)
  windows_image_id             = local.use_windows_image ? var.azure_windows_os_image_id : (local.use_windows_vhd ? azurerm_image.windows_vhd.0.id : null)
  use_linux_image              = var.azure_linux_os_image_id != null && var.azure_linux_os_image_id != ""
  use_linux_marketplace        = !local.use_linux_image && !local.use_linux_vhd
  use_linux_vhd                = !local.use_linux_image && var.azure_linux_os_vhd_url != null && var.azure_linux_os_vhd_url != ""
  use_windows_image            = var.azure_windows_os_image_id != null && var.azure_windows_os_image_id != ""
  use_windows_marketplace      = !local.use_windows_image && !local.use_windows_vhd
  use_windows_vhd              = !local.use_windows_image && var.azure_windows_os_vhd_url != null && var.azure_windows_os_vhd_url != ""
}

resource azurerm_image linux_vhd {
  name                         = "${azurerm_resource_group.rg.name}-linux-image"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name

  os_disk {
    os_type                    = "Linux"
    os_state                   = "Generalized"
    blob_uri                   = var.azure_linux_os_vhd_url
    size_gb                    = 100
    storage_type               = var.azure_linux_storage_type
  }

  count                        = local.use_linux_vhd ? 1 : 0
}

resource azurerm_image windows_vhd {
  name                         = "${azurerm_resource_group.rg.name}-windows-image"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name

  os_disk {
    os_type                    = "Windows"
    os_state                   = "Generalized"
    blob_uri                   = var.azure_windows_os_vhd_url
    size_gb                    = 256
    storage_type               = var.azure_windows_storage_type
  }

  count                        = local.use_windows_vhd ? 1 : 0
}