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

variable "region" {
  description = "Region of the service."
  type        = string
  default     = "europe-west1"
}

module "cloud_run" {
  source = "../.."

  project_id  = var.project_id
  region      = var.region
  config_file = "${path.module}/config.yaml"
}

output "uris" {
  value = module.cloud_run.service_uris
}
