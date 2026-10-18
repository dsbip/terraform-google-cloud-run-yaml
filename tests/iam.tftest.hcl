# Invokers (roles/run.invoker) and IAM grants on services and jobs.

mock_provider "google" {}

variables {
  project_id = "test-project"
  region     = "europe-west1"
}

run "service_and_job_grants" {
  command = plan

  variables {
    config_yaml = <<-EOT
      services:
        api:
          template: { containers: [{ image: app }] }
          invokers: [allUsers, "serviceAccount:a@test-project.iam.gserviceaccount.com", allUsers]
          iam:
            - role: roles/run.developer
              members: [group:devs@example.com, group:sre@example.com]
            - role: roles/run.developer
              members: [group:devs@example.com]          # duplicate
            - role: roles/run.invoker
              members: [allUsers]                        # already an invoker: skipped
            - role: roles/run.viewer
              members: [user:auditor@example.com]
              condition: { title: audit, expression: request.time < timestamp("2030-01-01T00:00:00Z") }
      jobs:
        etl:
          template: { containers: [{ image: app }] }
          invokers: ["serviceAccount:sched@test-project.iam.gserviceaccount.com"]
          iam:
            - role: roles/run.jobsExecutorWithOverrides
              members: ["serviceAccount:sched@test-project.iam.gserviceaccount.com"]
    EOT
  }

  assert {
    condition     = module.service["api"].invoker_members == tolist(["allUsers", "serviceAccount:a@test-project.iam.gserviceaccount.com"])
    error_message = "Unexpected invokers: ${jsonencode(module.service["api"].invoker_members)}"
  }
  assert {
    condition = module.service["api"].iam_members == tolist([
      "roles/run.developer group:devs@example.com",
      "roles/run.developer group:sre@example.com",
      "roles/run.viewer user:auditor@example.com [audit]",
    ])
    error_message = "Unexpected grants: ${jsonencode(module.service["api"].iam_members)}"
  }
  assert {
    condition = (
      module.job["etl"].invoker_members == tolist(["serviceAccount:sched@test-project.iam.gserviceaccount.com"]) &&
      module.job["etl"].iam_members == tolist(["roles/run.jobsExecutorWithOverrides serviceAccount:sched@test-project.iam.gserviceaccount.com"])
    )
    error_message = "Unexpected job grants."
  }
}

run "grant_resources_reference_the_service" {
  command = apply

  module {
    source = "./modules/service"
  }

  variables {
    name     = "api"
    template = { containers = [{ image = "app" }] }
    invokers = ["allUsers"]
    iam = [{
      role      = "roles/run.viewer"
      members   = ["user:auditor@example.com"]
      condition = { title = "audit", expression = "true", description = "Audit access." }
    }]
  }

  assert {
    condition = (
      google_cloud_run_v2_service_iam_member.invoker["allUsers"].name == "api" &&
      google_cloud_run_v2_service_iam_member.invoker["allUsers"].role == "roles/run.invoker" &&
      google_cloud_run_v2_service_iam_member.invoker["allUsers"].location == "europe-west1" &&
      google_cloud_run_v2_service_iam_member.invoker["allUsers"].project == "test-project"
    )
    error_message = "Wrong invoker grant."
  }
  assert {
    condition = (
      google_cloud_run_v2_service_iam_member.this["roles/run.viewer user:auditor@example.com [audit]"].condition[0].title == "audit" &&
      google_cloud_run_v2_service_iam_member.this["roles/run.viewer user:auditor@example.com [audit]"].condition[0].description == "Audit access."
    )
    error_message = "Wrong conditional grant."
  }
}

run "job_grant_resources_reference_the_job" {
  command = apply

  module {
    source = "./modules/job"
  }

  variables {
    name     = "etl"
    template = { containers = [{ image = "app" }] }
    invokers = ["serviceAccount:sched@test-project.iam.gserviceaccount.com"]
  }

  assert {
    condition = (
      google_cloud_run_v2_job_iam_member.invoker["serviceAccount:sched@test-project.iam.gserviceaccount.com"].name == "etl" &&
      google_cloud_run_v2_job_iam_member.invoker["serviceAccount:sched@test-project.iam.gserviceaccount.com"].role == "roles/run.invoker"
    )
    error_message = "Wrong job invoker grant."
  }
}
