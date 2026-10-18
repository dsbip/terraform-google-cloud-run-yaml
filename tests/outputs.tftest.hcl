# Outputs after an apply with the mocked provider (computed values filled in).

mock_provider "google" {
  mock_resource "google_cloud_run_v2_service" {
    defaults = {
      uri                   = "https://api-abc123-ew.a.run.app"
      urls                  = ["https://api-abc123-ew.a.run.app", "https://api-123456789.europe-west1.run.app"]
      latest_ready_revision = "api-00001-abc"
    }
  }
}

variables {
  project_id  = "test-project"
  region      = "europe-west1"
  config_yaml = <<-EOT
    services:
      api:
        template:
          service_account: run@test-project.iam.gserviceaccount.com
          containers: [{ image: app }]
        schedules:
          ping: { schedule: "*/5 * * * *", service_account_email: s@test-project.iam.gserviceaccount.com }
      retired:
        enabled: false
        template:
          containers: [{ image: app }]
    jobs:
      etl:
        template:
          service_account: batch@test-project.iam.gserviceaccount.com
          containers: [{ image: job }]
        schedules:
          nightly: { schedule: "0 2 * * *", service_account_email: s@test-project.iam.gserviceaccount.com }
  EOT
}

run "outputs_cover_every_enabled_entry" {
  command = apply

  assert {
    condition     = toset(keys(output.services)) == toset(["api"]) && toset(keys(output.jobs)) == toset(["etl"])
    error_message = "Outputs should list enabled entries only."
  }
  assert {
    condition = (
      output.services["api"].uri == "https://api-abc123-ew.a.run.app" &&
      output.services["api"].latest_ready_revision == "api-00001-abc" &&
      length(output.services["api"].urls) == 2 &&
      output.services["api"].service_account == "run@test-project.iam.gserviceaccount.com" &&
      output.services["api"].schedules == { ping = "api-ping" }
    )
    error_message = "Unexpected service output: ${jsonencode(output.services["api"])}"
  }
  assert {
    condition = (
      output.jobs["etl"].run_uri == "https://run.googleapis.com/v2/projects/test-project/locations/europe-west1/jobs/etl:run" &&
      output.jobs["etl"].service_account == "batch@test-project.iam.gserviceaccount.com" &&
      output.jobs["etl"].schedules == { nightly = "etl-nightly" } &&
      output.jobs["etl"].project_id == "test-project" &&
      output.jobs["etl"].region == "europe-west1"
    )
    error_message = "Unexpected job output: ${jsonencode(output.jobs["etl"])}"
  }
  assert {
    condition     = output.service_uris == { api = "https://api-abc123-ew.a.run.app" }
    error_message = "Unexpected service_uris."
  }
  assert {
    condition     = output.config.services["retired"].enabled == false && output.config.jobs["etl"].name == "etl"
    error_message = "config should include disabled entries."
  }
}
