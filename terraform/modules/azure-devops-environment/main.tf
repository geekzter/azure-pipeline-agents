data azuredevops_client_config current {}

locals {
  azdo_api_version             = "7.1"
  environment_id               = var.create_environment ? azuredevops_environment.environment.0.id : [for env in jsondecode(data.http.environments.0.response_body).value : env.id if env.name == var.name][0]
}

data http environments {
  url                          = "${data.azuredevops_client_config.current.organization_url}/${var.project_id}/_apis/pipelines/environments?api-version=${local.azdo_api_version}"
  request_headers = {
    Accept                     = "application/json"
    Authorization              = "Bearer ${data.external.azdo_token.result.accessToken}"
  }

  lifecycle {
    postcondition {
      condition                = tonumber(self.status_code) < 300
      error_message            = "Could not retrieve account information"
    }
    postcondition {
      condition                = tonumber(jsondecode(self.response_body).count) > 0
      error_message            = "No existing environments found"
    }
  }

  count                        = var.create_environment ? 0 : 1
}


data azuredevops_environment environment {
  environment_id               = local.environment_id
  project_id                   = var.project_id

  count                        = var.create_environment ? 0 : 1
}

resource azuredevops_environment environment {
  project_id                   = var.create_environment ? var.project_id : null
  name                         = var.name
  description                  = "Managed by Terraform"

  count                        = var.create_environment ? 1 : 0
}