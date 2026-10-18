terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.42.0, < 9.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
}

variable "project_id" {
  description = "Project to deploy to."
  type        = string
}

module "cloud_run" {
  source = "../.."

  project_id  = var.project_id
  config_file = "${path.module}/config.yaml"
  template_vars = {
    registry = "europe-docker.pkg.dev/${var.project_id}/apps"
    version  = "2.0.1"
  }
}

output "uris" {
  value = module.cloud_run.service_uris
}
