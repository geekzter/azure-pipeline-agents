output cloud_config {
  sensitive                    = true
  value                        = var.prepare_host ? data.cloudinit_config.user_data.0.rendered : null
}