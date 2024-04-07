variable "client_jwt" {
    type      = string
    default   = "${env("idToken")}"
    sensitive = true
}

