# The submodules on their own, without the YAML layer: typed inputs, their
# defaults and their input validation.

mock_provider "google" {}

variables {
  name       = "standalone"
  project_id = "test-project"
  region     = "europe-west1"
  template = {
    containers = [{ image = "us-docker.pkg.dev/cloudrun/container/hello" }]
  }
}

run "service_module_minimal" {
  command = plan

  module {
    source = "./modules/service"
  }

  assert {
    condition     = google_cloud_run_v2_service.this.name == "standalone" && google_cloud_run_v2_service.this.location == "europe-west1"
    error_message = "Wrong name or location."
  }
  assert {
    condition     = length(google_cloud_run_v2_service_iam_member.invoker) == 0 && length(module.schedule) == 0
    error_message = "No grants or schedules by default."
  }
}

run "service_name_is_validated" {
  command = plan

  module {
    source = "./modules/service"
  }

  variables {
    name = "this-service-name-is-far-too-long-for-cloud-run-xx"
  }

  expect_failures = [var.name]
}

run "service_ingress_and_deletion_policy_are_validated" {
  command = plan

  module {
    source = "./modules/service"
  }

  variables {
    ingress         = "PUBLIC"
    deletion_policy = "KEEP"
  }

  expect_failures = [var.ingress, var.deletion_policy]
}

run "service_template_rules" {
  command = plan

  module {
    source = "./modules/service"
  }

  variables {
    template = {
      containers = [
        { name = "a", image = "a", ports = { container_port = 8080 }, liveness_probe = { http_get = {}, grpc = {} } },
        { name = "b", image = "b", ports = { container_port = 9090 } },
      ]
      volumes = [{ name = "v", empty_dir = {}, nfs = { server = "s" } }]
    }
  }

  # Three template rules fail: one ingress container, one probe handler,
  # one volume kind.
  expect_failures = [var.template]
}

run "service_manual_scaling_needs_a_count" {
  command = plan

  module {
    source = "./modules/service"
  }

  variables {
    scaling = { scaling_mode = "MANUAL" }
  }

  expect_failures = [var.scaling]
}

run "job_module_minimal" {
  command = plan

  module {
    source = "./modules/job"
  }

  assert {
    condition     = google_cloud_run_v2_job.this.name == "standalone" && google_cloud_run_v2_job.this.template[0].template[0].containers[0].image == "us-docker.pkg.dev/cloudrun/container/hello"
    error_message = "Wrong job."
  }
  assert {
    condition     = output.run_uri == "https://run.googleapis.com/v2/projects/test-project/locations/europe-west1/jobs/standalone:run"
    error_message = "Wrong run URI."
  }
}

run "job_tokens_are_exclusive" {
  command = plan

  module {
    source = "./modules/job"
  }

  variables {
    start_execution_token = "a"
    run_execution_token   = "b"
  }

  expect_failures = [google_cloud_run_v2_job.this]
}

run "job_name_and_template_are_validated" {
  command = plan

  module {
    source = "./modules/job"
  }

  variables {
    name = "Job_1"
    template = {
      containers = []
    }
  }

  expect_failures = [var.name, var.template]
}

run "schedule_module_with_oidc" {
  command = plan

  module {
    source = "./modules/schedule"
  }

  variables {
    name       = "ping"
    schedule   = "*/5 * * * *"
    uri        = "https://example.a.run.app/ping"
    body       = "hello"
    headers    = { X-Test = "1" }
    oidc_token = { service_account_email = "s@test-project.iam.gserviceaccount.com", audience = "https://example.a.run.app" }
  }

  assert {
    condition = (
      google_cloud_scheduler_job.this.http_target[0].uri == "https://example.a.run.app/ping" &&
      google_cloud_scheduler_job.this.http_target[0].http_method == "POST" &&
      google_cloud_scheduler_job.this.http_target[0].body == base64encode("hello") &&
      google_cloud_scheduler_job.this.http_target[0].oidc_token[0].audience == "https://example.a.run.app"
    )
    error_message = "Wrong HTTP target."
  }
}

run "schedule_module_needs_exactly_one_token" {
  command = plan

  module {
    source = "./modules/schedule"
  }

  variables {
    name     = "none"
    schedule = "* * * * *"
    uri      = "https://example.com"
  }

  expect_failures = [google_cloud_scheduler_job.this]
}

run "schedule_module_validates_name_and_method" {
  command = plan

  module {
    source = "./modules/schedule"
  }

  variables {
    name        = "bad name!"
    schedule    = "* * * * *"
    uri         = "https://example.com"
    http_method = "FETCH"
    oauth_token = { service_account_email = "s@test-project.iam.gserviceaccount.com" }
  }

  expect_failures = [var.name, var.http_method]
}
