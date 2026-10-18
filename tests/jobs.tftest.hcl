# Job attributes, from YAML through modules/job to the planned
# google_cloud_run_v2_job. The YAML template is split into the provider's
# execution template and task template.

mock_provider "google" {}

variables {
  project_id = "test-project"
  region     = "europe-west1"
}

run "job_level_settings_and_the_split_template" {
  command = plan

  variables {
    config_yaml = <<-EOT
      jobs:
        etl:
          annotations: { team: data }
          client: terraform
          client_version: "1.9"
          launch_stage: BETA
          deletion_protection: false
          deletion_policy: PREVENT
          binary_authorization: { use_default: true }
          run_execution_token: once
          template:
            labels: { workload: etl }
            annotations: { note: x }
            parallelism: 4
            task_count: 20
            max_retries: 5
            timeout: 3600s
            service_account: batch@test-project.iam.gserviceaccount.com
            execution_environment: EXECUTION_ENVIRONMENT_GEN2
            encryption_key: projects/test-project/locations/europe-west1/keyRings/r/cryptoKeys/k
            gpu_zonal_redundancy_disabled: true
            node_selector: { accelerator: nvidia-l4 }
            vpc_access:
              network_interfaces: [{ subnetwork: batch }]
              egress: ALL_TRAFFIC
            containers:
              - image: etl
                resources:
                  limits: { cpu: "4", memory: 16Gi, nvidia.com/gpu: "1" }
    EOT
  }

  assert {
    condition = (
      module.job["etl"].job.annotations == tomap({ team = "data" }) &&
      module.job["etl"].job.client == "terraform" &&
      module.job["etl"].job.client_version == "1.9" &&
      module.job["etl"].job.launch_stage == "BETA" &&
      module.job["etl"].job.deletion_protection == false &&
      module.job["etl"].job.deletion_policy == "PREVENT" &&
      module.job["etl"].job.binary_authorization[0].use_default == true
    )
    error_message = "Wrong job-level attributes."
  }
  assert {
    condition     = module.job["etl"].job.start_execution_token == null && module.job["etl"].job.run_execution_token == "once"
    error_message = "run_execution_token was not passed."
  }
  assert {
    condition = (
      module.job["etl"].job.template[0].labels == tomap({ workload = "etl" }) &&
      module.job["etl"].job.template[0].annotations == tomap({ note = "x" }) &&
      module.job["etl"].job.template[0].parallelism == 4 &&
      module.job["etl"].job.template[0].task_count == 20
    )
    error_message = "The execution template should hold labels, annotations, parallelism and task_count."
  }
  assert {
    condition = (
      module.job["etl"].job.template[0].template[0].max_retries == 5 &&
      module.job["etl"].job.template[0].template[0].timeout == "3600s" &&
      module.job["etl"].job.template[0].template[0].service_account == "batch@test-project.iam.gserviceaccount.com" &&
      module.job["etl"].job.template[0].template[0].execution_environment == "EXECUTION_ENVIRONMENT_GEN2" &&
      module.job["etl"].job.template[0].template[0].encryption_key == "projects/test-project/locations/europe-west1/keyRings/r/cryptoKeys/k" &&
      module.job["etl"].job.template[0].template[0].gpu_zonal_redundancy_disabled == true
    )
    error_message = "The task template should hold retries, timeout, service account, environment, key and GPU redundancy."
  }
  assert {
    condition = (
      module.job["etl"].job.template[0].template[0].node_selector[0].accelerator == "nvidia-l4" &&
      module.job["etl"].job.template[0].template[0].vpc_access[0].egress == "ALL_TRAFFIC" &&
      module.job["etl"].job.template[0].template[0].vpc_access[0].network_interfaces[0].subnetwork == "batch"
    )
    error_message = "Wrong node selector or VPC access."
  }
}

run "job_containers_and_volumes" {
  command = plan

  variables {
    config_yaml = <<-EOT
      jobs:
        task:
          template:
            containers:
              - name: main
                image: app
                command: [python]
                args: [-m, task]
                working_dir: /app
                depends_on: [proxy]
                env: { BATCH: 100 }
                secret_env:
                  TOKEN: { secret: token }
                resources:
                  limits: { cpu: "2", memory: 4Gi }
                volume_mounts:
                  - { name: work, mount_path: /work }
                  - { name: creds, mount_path: /creds }
              - name: proxy
                image: proxy
                startup_probe:
                  failure_threshold: 30
                  http_get:
                    path: /startup
                    port: 9090
                    http_headers: [{ name: X-Probe, value: "1" }]
            volumes:
              - name: work
                empty_dir: { size_limit: 1Gi }
              - name: creds
                secret:
                  secret: creds
                  items:
                    - { path: creds.json }
                    - { path: old.json, version: "2", mode: "0400" }
              - name: sql
                cloud_sql_instance: { instances: ["p:r:i"] }
    EOT
  }

  assert {
    condition = (
      module.job["task"].job.template[0].template[0].containers[0].command == tolist(["python"]) &&
      module.job["task"].job.template[0].template[0].containers[0].args == tolist(["-m", "task"]) &&
      module.job["task"].job.template[0].template[0].containers[0].working_dir == "/app" &&
      module.job["task"].job.template[0].template[0].containers[0].depends_on == tolist(["proxy"]) &&
      module.job["task"].job.template[0].template[0].containers[0].resources[0].limits == tomap({ cpu = "2", memory = "4Gi" })
    )
    error_message = "Wrong job container."
  }
  assert {
    condition = toset([
      for e in module.job["task"].job.template[0].template[0].containers[0].env :
      e.value != null ? "${e.name}=${e.value}" : "${e.name}=secret:${e.value_source[0].secret_key_ref[0].secret}@${e.value_source[0].secret_key_ref[0].version}"
    ]) == toset(["BATCH=100", "TOKEN=secret:token@latest"])
    error_message = "Unexpected env: ${jsonencode(module.job["task"].job.template[0].template[0].containers[0].env)}"
  }
  assert {
    condition = (
      module.job["task"].job.template[0].template[0].containers[1].startup_probe[0].failure_threshold == 30 &&
      module.job["task"].job.template[0].template[0].containers[1].startup_probe[0].http_get[0].port == 9090 &&
      module.job["task"].job.template[0].template[0].containers[1].startup_probe[0].http_get[0].http_headers[0].value == "1"
    )
    error_message = "Wrong startup probe."
  }
  assert {
    condition = jsonencode(module.job["task"].job.template[0].template[0].volumes[1].secret[0].items) == jsonencode([
      { mode = null, path = "creds.json", version = "latest" },
      { mode = 256, path = "old.json", version = "2" },
    ])
    error_message = "Job secret items need a version (default latest): ${jsonencode(module.job["task"].job.template[0].template[0].volumes[1].secret[0].items)}"
  }
  assert {
    condition     = module.job["task"].job.template[0].template[0].volumes[2].cloud_sql_instance[0].instances == tolist(["p:r:i"])
    error_message = "Wrong Cloud SQL volume."
  }
}

run "run_uri_is_known_at_plan_time" {
  command = plan

  variables {
    config_yaml = <<-EOT
      jobs:
        nightly:
          project_id: other-project
          region: us-east1
          template:
            containers: [{ image: app }]
    EOT
  }

  assert {
    condition     = module.job["nightly"].run_uri == "https://run.googleapis.com/v2/projects/other-project/locations/us-east1/jobs/nightly:run"
    error_message = "Unexpected run URI: ${module.job["nightly"].run_uri}"
  }
}
