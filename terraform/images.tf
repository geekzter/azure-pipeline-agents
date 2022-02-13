locals {
  linux_image_id               = local.use_linux_image ? var.linux_os_image_id : (local.use_linux_vhd ? azurerm_image.linux_vhd.0.id : null)
  windows_image_id             = local.use_windows_image ? var.windows_os_image_id : (local.use_windows_vhd ? azurerm_image.windows_vhd.0.id : null)
  use_linux_image              = var.linux_os_image_id != null && var.linux_os_image_id != ""
  use_linux_marketplace        = !local.use_linux_image && !local.use_linux_vhd
  use_linux_vhd                = !local.use_linux_image && var.linux_os_vhd_url != null && var.linux_os_vhd_url != ""
  use_windows_image            = var.windows_os_image_id != null && var.windows_os_image_id != ""
  use_windows_marketplace      = !local.use_windows_image && !local.use_windows_vhd
  use_windows_vhd              = !local.use_windows_image && var.windows_os_vhd_url != null && var.windows_os_vhd_url != ""
}

resource azurerm_image linux_vhd {
  name                         = "${azurerm_resource_group.rg.name}-linux-image"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name

  os_disk {
    os_type                    = "Linux"
    os_state                   = "Generalized"
    blob_uri                   = var.linux_os_vhd_url
    size_gb                    = 100
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
    blob_uri                   = var.windows_os_vhd_url
    size_gb                    = 256
  }

  count                        = local.use_windows_vhd ? 1 : 0
}