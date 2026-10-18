# Every example configuration, planned with a mocked provider. Each run checks
# the behaviour the example's README describes. (tests/python plans the same
# examples with the real provider.)

mock_provider "google" {}

variables {
  project_id = "example-project"
}

run "basic" {
  command = plan

  variables {
    region      = "europe-west1"
    config_file = "examples/basic/config.yaml"
  }

  assert {
    condition     = toset(keys(module.service)) == toset(["hello"]) && module.service["hello"].invoker_members == tolist(["allUsers"])
    error_message = "basic: one public service expected."
  }
  assert {
    condition     = module.service["hello"].service.deletion_protection == false
    error_message = "basic: the example must be destroyable."
  }
}

run "services" {
  command = plan

  variables {
    config_file   = "examples/services/config.yaml"
    template_vars = { region = "europe-west1", registry = "r", version = "1.8.0", project_number = "123" }
    labels        = { managed-by = "terraform" }
  }

  assert {
    condition     = toset(keys(module.service)) == toset(["storefront", "orders-api", "catalog-grpc", "admin"])
    error_message = "services: four services expected."
  }
  assert {
    condition = (
      module.service["orders-api"].service.template[0].scaling[0].min_instance_count == 2 &&
      module.service["orders-api"].service.template[0].scaling[0].max_instance_count == 100 &&
      module.service["storefront"].service.template[0].scaling[0].max_instance_count == 20
    )
    error_message = "services: scaling defaults and overrides."
  }
  assert {
    condition = (
      module.service["orders-api"].service.template[0].containers[0].resources[0].limits == tomap({ cpu = "2", memory = "1Gi" }) &&
      module.service["admin"].service.template[0].containers[0].resources[0].limits == tomap({ cpu = "1", memory = "1Gi" }) &&
      module.service["catalog-grpc"].service.template[0].containers[0].resources[0].limits == tomap({ cpu = "1", memory = "512Mi" })
    )
    error_message = "services: container resource defaults merge per key."
  }
  assert {
    condition     = toset([for e in module.service["storefront"].service.template[0].containers[0].env : e.name]) == toset(["LOG_LEVEL", "GOOGLE_CLOUD_PROJECT", "API_URL"])
    error_message = "services: storefront env merges with the defaults."
  }
  assert {
    condition = (
      module.service["catalog-grpc"].service.template[0].containers[0].ports[0].name == "h2c" &&
      module.service["admin"].service.ingress == "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" &&
      module.service["admin"].service.default_uri_disabled == true
    )
    error_message = "services: gRPC and admin settings."
  }
  assert {
    condition     = module.service["orders-api"].service.labels == tomap({ managed-by = "terraform", app = "shop", tier = "critical" })
    error_message = "services: labels."
  }
}

run "sidecars_and_volumes" {
  command = plan

  variables {
    config_file   = "examples/sidecars-and-volumes/config.yaml"
    template_vars = { registry = "r", version = "2.0.1" }
  }

  assert {
    condition = (
      [for c in module.service["web"].service.template[0].containers : c.name] == ["nginx", "app", "otel-collector"] &&
      module.service["web"].service.template[0].containers[0].depends_on == tolist(["app"])
    )
    error_message = "sidecars-and-volumes: three containers with nginx depending on the app."
  }
  assert {
    condition = (
      module.service["web"].service.template[0].volumes[2].secret[0].default_mode == 292 &&
      module.service["reports"].service.template[0].volumes[3].secret[0].items[0].mode == 256
    )
    error_message = "sidecars-and-volumes: quoted octal modes."
  }
  assert {
    condition = (
      length(module.service["reports"].service.template[0].volumes[0].cloud_sql_instance[0].instances) == 2 &&
      module.service["reports"].service.template[0].volumes[1].gcs[0].bucket == "example-project-reports" &&
      module.service["reports"].service.template[0].volumes[2].nfs[0].read_only == true
    )
    error_message = "sidecars-and-volumes: Cloud SQL, GCS and NFS volumes."
  }
}

run "jobs" {
  command = plan

  variables {
    config_file   = "examples/jobs/config.yaml"
    template_vars = { registry = "r", version = "2026.10.1" }
  }

  assert {
    condition     = toset(keys(module.job)) == toset(["nightly-etl", "db-migrate", "thumbnail-backfill", "cleanup"])
    error_message = "jobs: four jobs expected."
  }
  assert {
    condition = (
      module.job["nightly-etl"].job.template[0].task_count == 100 &&
      module.job["nightly-etl"].job.template[0].parallelism == 10 &&
      module.job["nightly-etl"].job.template[0].template[0].max_retries == 5 &&
      module.job["thumbnail-backfill"].job.template[0].template[0].max_retries == 2
    )
    error_message = "jobs: task settings and defaults."
  }
  assert {
    condition     = module.job["db-migrate"].job.run_execution_token == "2026.10.1"
    error_message = "jobs: db-migrate runs once per release."
  }
  assert {
    condition = (
      module.job["thumbnail-backfill"].job.template[0].template[0].containers[0].image == "r/batch-tools:2026.10.1" &&
      module.job["db-migrate"].job.template[0].template[0].containers[0].image == "r/migrations:2026.10.1"
    )
    error_message = "jobs: images from defaults.job_container unless set."
  }
  assert {
    condition     = jsondecode(base64decode(module.job["nightly-etl"].scheduler_jobs["monthly-full"].http_target[0].body)).overrides.containerOverrides[0] == { name = "etl", args = ["--mode=full"] }
    error_message = "jobs: monthly-full overrides the etl container's arguments."
  }
}

run "traffic_management" {
  command = plan

  variables {
    config_file   = "examples/traffic-management/config.yaml"
    template_vars = { registry = "r", old_release = "v41", new_release = "v42" }
  }

  assert {
    condition     = [for t in module.service["checkout"].service.traffic : "${t.revision}=${t.percent}"] == ["checkout-v41=90", "checkout-v42=10"]
    error_message = "traffic-management: 90/10 canary."
  }
  assert {
    condition     = module.service["search"].service.template[0].revision == "search-v42" && [for t in module.service["search"].service.traffic : t.tag] == ["blue", "green"]
    error_message = "traffic-management: blue/green."
  }
  assert {
    condition     = module.service["docs"].service.traffic[0].type == "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    error_message = "traffic-management: LATEST is expanded."
  }
}

run "scheduled_workloads" {
  command = plan

  variables {
    config_file   = "examples/scheduled-workloads/config.yaml"
    template_vars = { registry = "r" }
  }

  assert {
    condition     = module.service["maintenance-api"].schedules == { cache-warmup = "maintenance-api-cache-warmup", daily-digest = "maintenance-api-daily-digest", quarterly-report = "maintenance-api-quarterly-report" }
    error_message = "scheduled-workloads: three service schedules."
  }
  assert {
    condition = (
      module.service["maintenance-api"].scheduler_jobs["quarterly-report"].region == "us-central1" &&
      module.service["maintenance-api"].scheduler_jobs["quarterly-report"].paused == true &&
      module.service["maintenance-api"].scheduler_jobs["daily-digest"].retry_config[0].retry_count == 3
    )
    error_message = "scheduled-workloads: schedule options."
  }
  assert {
    condition     = jsondecode(base64decode(module.job["backup"].scheduler_jobs["weekly-verify"].http_target[0].body)).overrides.timeout == "3600s"
    error_message = "scheduled-workloads: job override."
  }
}

run "gpu_inference" {
  command = plan

  variables {
    config_file   = "examples/gpu-inference/config.yaml"
    template_vars = { registry = "r" }
  }

  assert {
    condition = (
      module.service["llm-inference"].service.template[0].node_selector[0].accelerator == "nvidia-l4" &&
      module.service["llm-inference"].service.template[0].containers[0].resources[0].limits["nvidia.com/gpu"] == "1" &&
      module.job["fine-tune"].job.template[0].template[0].node_selector[0].accelerator == "nvidia-l4"
    )
    error_message = "gpu-inference: GPUs on the service and the job."
  }
}

run "multi_environment_dev" {
  command = plan

  variables {
    config_file   = "examples/multi-environment/config.yaml"
    template_vars = { env = "dev", image_tag = "main", min_instances = 0, max_instances = 2 }
  }

  assert {
    condition     = toset(keys(module.service)) == toset(["api", "api-preview"]) && length(module.job["reindex"].schedules) == 0
    error_message = "multi-environment: dev has the preview service and no schedule."
  }
  assert {
    condition = (
      module.service["api"].service.deletion_protection == false &&
      module.service["api"].service.template[0].containers[0].resources[0].limits["memory"] == "512Mi" &&
      module.job["reindex"].job.template[0].task_count == 2
    )
    error_message = "multi-environment: dev sizing."
  }
}

run "multi_environment_prod" {
  command = plan

  variables {
    config_file   = "examples/multi-environment/config.yaml"
    template_vars = { env = "prod", image_tag = "1.8.3", min_instances = 2, max_instances = 50 }
  }

  assert {
    condition     = toset(keys(module.service)) == toset(["api"]) && local.services["api-preview"].enabled == false
    error_message = "multi-environment: prod has no preview service."
  }
  assert {
    condition = (
      module.service["api"].service.deletion_protection == true &&
      module.service["api"].service.template[0].containers[0].resources[0].limits["memory"] == "2Gi" &&
      module.service["api"].service.template[0].containers[0].resources[0].cpu_idle == false &&
      module.service["api"].service.template[0].scaling[0].min_instance_count == 2 &&
      module.service["api"].invoker_members == tolist(["serviceAccount:gateway@example-project.iam.gserviceaccount.com"])
    )
    error_message = "multi-environment: prod api settings."
  }
  assert {
    condition     = module.job["reindex"].job.template[0].task_count == 20 && module.job["reindex"].schedules == { nightly = "reindex-nightly" }
    error_message = "multi-environment: prod reindex settings."
  }
}

run "complete" {
  command = plan

  variables {
    config_file   = "examples/complete/config.yaml"
    template_vars = { registry = "r" }
    labels        = { managed-by = "terraform" }
  }

  assert {
    condition = (
      toset(keys(module.service)) == toset(["storefront", "catalog", "admin", "reports", "recommender", "status"]) &&
      toset(keys(module.job)) == toset(["etl", "migrate", "embeddings"])
    )
    error_message = "complete: six services and three jobs enabled."
  }
  assert {
    condition     = module.service["storefront"].name == "shop-storefront" && module.job["etl"].name == "shop-etl"
    error_message = "complete: names differ from keys."
  }
  assert {
    condition     = module.service["reports"].project_id == "shop-analytics" && module.service["reports"].region == "europe-west4" && module.job["embeddings"].region == "us-central1"
    error_message = "complete: project and region overrides."
  }
  assert {
    condition = (
      module.service["storefront"].service.template[0].volumes[1].secret[0].default_mode == 292 &&
      module.service["storefront"].service.template[0].volumes[1].secret[0].items[0].mode == 288
    )
    error_message = "complete: octal modes."
  }
  assert {
    condition     = module.service["admin"].service.deletion_protection == true && module.service["admin"].service.deletion_policy == "PREVENT"
    error_message = "complete: admin is protected."
  }
  assert {
    condition     = module.job["embeddings"].job.template[0].template[0].containers[0].image == "r/batch:2.1.0"
    error_message = "complete: embeddings uses the default job image."
  }
}
