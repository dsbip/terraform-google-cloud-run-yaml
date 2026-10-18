# The submodules work without YAML: modules/service and modules/job deploy one
# service or job from typed inputs, and modules/schedule creates a Cloud
# Scheduler HTTP job for any target.

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

locals {
  region    = "europe-west1"
  scheduler = "scheduler@${var.project_id}.iam.gserviceaccount.com"
}

module "hello" {
  source = "../../modules/service"

  name                = "hello"
  project_id          = var.project_id
  region              = local.region
  deletion_protection = false

  template = {
    containers = [{
      image = "us-docker.pkg.dev/cloudrun/container/hello"
      env   = { GREETING = "hi" }
      resources = {
        limits = { cpu = "1", memory = "512Mi" }
      }
    }]
  }

  invokers = ["allUsers"]
}

module "report" {
  source = "../../modules/job"

  name                = "report"
  project_id          = var.project_id
  region              = local.region
  deletion_protection = false

  template = {
    task_count = 4
    containers = [{
      image      = "us-docker.pkg.dev/cloudrun/container/job"
      secret_env = { API_TOKEN = { secret = "report-token" } }
    }]
  }

  invokers = ["serviceAccount:${local.scheduler}"]
  schedules = {
    daily = {
      schedule              = "0 6 * * *"
      service_account_email = local.scheduler
    }
  }
}

# A schedule for something the modules don't manage: a Workflows execution.
module "workflow_trigger" {
  source = "../../modules/schedule"

  name       = "nightly-workflow"
  project_id = var.project_id
  region     = local.region
  schedule   = "30 1 * * *"
  uri        = "https://workflowexecutions.googleapis.com/v1/projects/${var.project_id}/locations/${local.region}/workflows/nightly/executions"
  body       = jsonencode({ argument = jsonencode({ source = "scheduler" }) })
  headers    = { "Content-Type" = "application/json" }

  oauth_token = { service_account_email = local.scheduler }
}

output "hello_uri" {
  value = module.hello.uri
}

output "report_schedules" {
  value = module.report.schedules
}
