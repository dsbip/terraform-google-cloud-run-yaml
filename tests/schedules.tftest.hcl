# Schedules: Cloud Scheduler jobs that call services (OIDC) and execute jobs
# (Cloud Run Admin API, OAuth), through modules/schedule.

mock_provider "google" {
  mock_resource "google_cloud_run_v2_service" {
    defaults = {
      uri = "https://api-abc123-ew.a.run.app"
    }
  }
}

variables {
  project_id = "test-project"
  region     = "europe-west1"
}

run "service_schedule_with_every_option" {
  command = apply

  variables {
    config_yaml = <<-EOT
      services:
        api:
          template:
            containers: [{ image: app }]
          schedules:
            digest:
              schedule: "0 7 * * 1-5"
              time_zone: America/New_York
              description: Weekday digest.
              paused: true
              region: us-central1
              service_account_email: sched@test-project.iam.gserviceaccount.com
              path: /tasks/digest
              http_method: PUT
              headers: { Content-Type: application/json }
              body: '{"dry_run": false}'
              audience: https://api.example.com
              attempt_deadline: 120s
              retry_config:
                retry_count: 3
                max_retry_duration: 600s
                min_backoff_duration: 5s
                max_backoff_duration: 60s
                max_doublings: 2
            ping:
              schedule: "*/5 * * * *"
              service_account_email: sched@test-project.iam.gserviceaccount.com
    EOT
  }

  assert {
    condition = (
      module.service["api"].scheduler_jobs["digest"].name == "api-digest" &&
      module.service["api"].scheduler_jobs["digest"].region == "us-central1" &&
      module.service["api"].scheduler_jobs["digest"].schedule == "0 7 * * 1-5" &&
      module.service["api"].scheduler_jobs["digest"].time_zone == "America/New_York" &&
      module.service["api"].scheduler_jobs["digest"].description == "Weekday digest." &&
      module.service["api"].scheduler_jobs["digest"].paused == true &&
      module.service["api"].scheduler_jobs["digest"].attempt_deadline == "120s"
    )
    error_message = "Wrong scheduler job attributes."
  }
  assert {
    condition = (
      module.service["api"].scheduler_jobs["digest"].http_target[0].uri == "https://api-abc123-ew.a.run.app/tasks/digest" &&
      module.service["api"].scheduler_jobs["digest"].http_target[0].http_method == "PUT" &&
      module.service["api"].scheduler_jobs["digest"].http_target[0].headers == tomap({ "Content-Type" = "application/json" }) &&
      base64decode(module.service["api"].scheduler_jobs["digest"].http_target[0].body) == "{\"dry_run\": false}"
    )
    error_message = "Wrong HTTP target: ${jsonencode(module.service["api"].scheduler_jobs["digest"].http_target)}"
  }
  assert {
    condition = (
      module.service["api"].scheduler_jobs["digest"].http_target[0].oidc_token[0].service_account_email == "sched@test-project.iam.gserviceaccount.com" &&
      module.service["api"].scheduler_jobs["digest"].http_target[0].oidc_token[0].audience == "https://api.example.com" &&
      length(module.service["api"].scheduler_jobs["digest"].http_target[0].oauth_token) == 0
    )
    error_message = "Service schedules must use an OIDC token."
  }
  assert {
    condition = (
      module.service["api"].scheduler_jobs["digest"].retry_config[0].retry_count == 3 &&
      module.service["api"].scheduler_jobs["digest"].retry_config[0].max_retry_duration == "600s" &&
      module.service["api"].scheduler_jobs["digest"].retry_config[0].min_backoff_duration == "5s" &&
      module.service["api"].scheduler_jobs["digest"].retry_config[0].max_backoff_duration == "60s" &&
      module.service["api"].scheduler_jobs["digest"].retry_config[0].max_doublings == 2
    )
    error_message = "Wrong retry_config."
  }
  assert {
    condition = (
      module.service["api"].scheduler_jobs["ping"].region == "europe-west1" &&
      module.service["api"].scheduler_jobs["ping"].http_target[0].uri == "https://api-abc123-ew.a.run.app/" &&
      module.service["api"].scheduler_jobs["ping"].http_target[0].http_method == "POST" &&
      module.service["api"].scheduler_jobs["ping"].http_target[0].oidc_token[0].audience == "https://api-abc123-ew.a.run.app" &&
      module.service["api"].scheduler_jobs["ping"].http_target[0].body == null
    )
    error_message = "Defaults: service region, path /, POST, audience = service URL, no body."
  }
  assert {
    condition     = module.service["api"].schedules == { digest = "api-digest", ping = "api-ping" }
    error_message = "Unexpected schedules output: ${jsonencode(module.service["api"].schedules)}"
  }
}

run "job_schedules_call_the_admin_api" {
  command = plan

  variables {
    config_yaml = <<-EOT
      jobs:
        etl:
          template:
            containers:
              - { name: main, image: app }
              - { name: proxy, image: proxy }
          schedules:
            nightly:
              schedule: "0 2 * * *"
              service_account_email: sched@test-project.iam.gserviceaccount.com
            full:
              schedule: "0 1 1 * *"
              service_account_email: sched@test-project.iam.gserviceaccount.com
              overrides:
                args: [--full]
                env: { MODE: full, SIZE: 10 }
                task_count: 100
                timeout: 7200s
            sidecar-args:
              schedule: "0 3 * * *"
              service_account_email: sched@test-project.iam.gserviceaccount.com
              overrides:
                container: proxy
                args: [--verbose]
            count-only:
              schedule: "0 4 * * *"
              service_account_email: sched@test-project.iam.gserviceaccount.com
              overrides: { task_count: 5 }
    EOT
  }

  assert {
    condition = (
      module.job["etl"].scheduler_jobs["nightly"].http_target[0].uri == "https://run.googleapis.com/v2/projects/test-project/locations/europe-west1/jobs/etl:run" &&
      module.job["etl"].scheduler_jobs["nightly"].http_target[0].http_method == "POST" &&
      module.job["etl"].scheduler_jobs["nightly"].http_target[0].body == null &&
      module.job["etl"].scheduler_jobs["nightly"].http_target[0].headers == null
    )
    error_message = "A schedule without overrides posts an empty request."
  }
  assert {
    condition = (
      module.job["etl"].scheduler_jobs["nightly"].http_target[0].oauth_token[0].service_account_email == "sched@test-project.iam.gserviceaccount.com" &&
      module.job["etl"].scheduler_jobs["nightly"].http_target[0].oauth_token[0].scope == "https://www.googleapis.com/auth/cloud-platform" &&
      length(module.job["etl"].scheduler_jobs["nightly"].http_target[0].oidc_token) == 0
    )
    error_message = "Job schedules must use an OAuth token."
  }
  assert {
    condition = jsondecode(base64decode(module.job["etl"].scheduler_jobs["full"].http_target[0].body)) == {
      overrides = {
        containerOverrides = [{ name = "main", args = ["--full"], env = [{ name = "MODE", value = "full" }, { name = "SIZE", value = "10" }] }]
        taskCount          = 100
        timeout            = "7200s"
      }
    }
    error_message = "Unexpected body: ${base64decode(module.job["etl"].scheduler_jobs["full"].http_target[0].body)}"
  }
  assert {
    condition     = module.job["etl"].scheduler_jobs["full"].http_target[0].headers == tomap({ "Content-Type" = "application/json" })
    error_message = "A request with a body needs a JSON content type."
  }
  assert {
    condition     = jsondecode(base64decode(module.job["etl"].scheduler_jobs["sidecar-args"].http_target[0].body)).overrides.containerOverrides[0].name == "proxy"
    error_message = "overrides.container should select the container."
  }
  assert {
    condition     = jsondecode(base64decode(module.job["etl"].scheduler_jobs["count-only"].http_target[0].body)) == { overrides = { taskCount = 5 } }
    error_message = "Only the task count should be overridden: ${base64decode(module.job["etl"].scheduler_jobs["count-only"].http_target[0].body)}"
  }
}

run "unnamed_single_container_overrides_have_no_name" {
  command = plan

  variables {
    config_yaml = <<-EOT
      jobs:
        simple:
          template:
            containers: [{ image: app }]
          schedules:
            run:
              schedule: "0 * * * *"
              service_account_email: sched@test-project.iam.gserviceaccount.com
              overrides: { args: [--x] }
    EOT
  }

  assert {
    condition     = jsondecode(base64decode(module.job["simple"].scheduler_jobs["run"].http_target[0].body)) == { overrides = { containerOverrides = [{ args = ["--x"] }] } }
    error_message = "Unexpected body: ${base64decode(module.job["simple"].scheduler_jobs["run"].http_target[0].body)}"
  }
}
