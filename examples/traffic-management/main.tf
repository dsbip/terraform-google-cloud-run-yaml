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

variable "old_release" {
  description = "Release currently serving (revision suffix)."
  type        = string
  default     = "v41"
}

variable "new_release" {
  description = "Release being rolled out (revision suffix)."
  type        = string
  default     = "v42"
}

module "cloud_run" {
  source = "../.."

  project_id  = var.project_id
  config_file = "${path.module}/config.yaml"
  template_vars = {
    registry    = "us-docker.pkg.dev/${var.project_id}/web"
    old_release = var.old_release
    new_release = var.new_release
  }
}

output "services" {
  value = module.cloud_run.services
}
