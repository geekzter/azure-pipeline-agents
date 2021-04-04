# See https://www.terraform.io/docs/backends/types/azurerm.html

terraform {
  backend "azurerm" {
    resource_group_name  = "automation"
    # Use partial configuration, as we do not want to expose these details
    storage_account_name = "ewterraformstate"
    container_name       = "pipelineagents" 
    key                  = "terraform.tfstate"
    # https://ewterraformstate.blob.core.windows.net/pipelineagents?sp=racwl&st=2021-04-04T16:53:32Z&se=2022-01-12T01:53:32Z&spr=https&sv=2020-02-10&sr=c&sig=N5Ks3J7eUfD7FPm2HQNSbG4qnFmLvjATQ%2BYLR3pSaoc%3D
    sas_token            = "sp=racwl&st=2021-04-04T16:53:32Z&se=2022-01-12T01:53:32Z&spr=https&sv=2020-02-10&sr=c&sig=N5Ks3J7eUfD7FPm2HQNSbG4qnFmLvjATQ%2BYLR3pSaoc%3D"
  }
}