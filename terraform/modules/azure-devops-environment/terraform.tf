data external azdo_token {
  program                      = [
    "az", "account", "get-access-token", 
    "--resource", "499b84ac-1321-427f-aa17-267ca6975798", # Azure DevOps
    "--query","{accessToken:accessToken}",
    "-o","json"
  ]
}

terraform {
  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
    }
    http = {
      source  = "hashicorp/http"
    }
  }
}