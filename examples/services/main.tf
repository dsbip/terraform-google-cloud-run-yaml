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
  description = "Region of the services."
  type        = string
  default     = "europe-west1"
}

variable "registry" {
  description = "Artifact Registry path that holds the images."
  type        = string
  default     = "europe-docker.pkg.dev/example-project/shop"
}

variable "project_number" {
  description = "Project number, used in the services' deterministic URLs (https://SERVICE-NUMBER.REGION.run.app)."
  type        = string
  default     = "123456789012"
}

variable "version_tag" {
  description = "Image tag to deploy."
  type        = string
  default     = "1.8.0"
}

module "cloud_run" {
  source = "../.."

  project_id  = var.project_id
  config_file = "${path.module}/config.yaml"
  template_vars = {
    region         = var.region
    registry       = var.registry
    version        = var.version_tag
    project_number = var.project_number
  }
  labels = { managed-by = "terraform" }
}

output "uris" {
  value = module.cloud_run.service_uris
}
