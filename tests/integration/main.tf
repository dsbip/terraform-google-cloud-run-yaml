# Live-test fixture (see docs/testing.md): one service and one job, plus a
# paused schedule when a scheduler service account is given.

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
  description = "Project to test in."
  type        = string
}

variable "region" {
  description = "Region to test in."
  type        = string
  default     = "europe-west1"
}

variable "suffix" {
  description = "Random suffix that keeps names of concurrent runs apart."
  type        = string
}

variable "revision" {
  description = "Changes a description, a label and environment variables (in-place update test)."
  type        = number
  default     = 1
}

variable "test_member" {
  description = "Optional IAM member granted roles/run.invoker on the service."
  type        = string
  default     = ""
}

variable "scheduler_service_account" {
  description = "Optional service account email for a paused job schedule."
  type        = string
  default     = ""
}

module "cloud_run" {
  source = "../.."

  project_id  = var.project_id
  region      = var.region
  config_file = "${path.module}/cloud-run.yaml"
  template_vars = {
    suffix                    = var.suffix
    revision                  = var.revision
    test_member               = var.test_member
    scheduler_service_account = var.scheduler_service_account
  }
}

output "services" {
  value = module.cloud_run.services
}

output "jobs" {
  value = module.cloud_run.jobs
}
