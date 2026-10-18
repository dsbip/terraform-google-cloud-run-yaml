terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.42.0, < 9.0.0"
    }
  }
}

provider "google" {}

variable "environments" {
  description = "Environments to deploy, each with its own project and settings."
  type = map(object({
    project_id    = string
    image_tag     = string
    min_instances = number
    max_instances = number
  }))
  default = {
    dev     = { project_id = "example-dev", image_tag = "main", min_instances = 0, max_instances = 2 }
    staging = { project_id = "example-staging", image_tag = "1.9.0-rc.1", min_instances = 0, max_instances = 5 }
    prod    = { project_id = "example-prod", image_tag = "1.8.3", min_instances = 2, max_instances = 50 }
  }
}

module "cloud_run" {
  source   = "../.."
  for_each = var.environments

  project_id  = each.value.project_id
  config_file = "${path.module}/config.yaml"
  template_vars = {
    env           = each.key
    image_tag     = each.value.image_tag
    min_instances = each.value.min_instances
    max_instances = each.value.max_instances
  }
}

output "uris" {
  value = { for env, m in module.cloud_run : env => m.service_uris }
}
