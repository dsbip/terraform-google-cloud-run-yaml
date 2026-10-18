# Service attributes, from YAML through modules/service to the planned
# google_cloud_run_v2_service.

mock_provider "google" {}

variables {
  project_id = "test-project"
  region     = "europe-west1"
}

run "service_level_settings" {
  command = plan

  variables {
    config_yaml = <<-EOT
      services:
        api:
          description: The API.
          annotations: { team: core }
          client: terraform
          client_version: "1.9"
          ingress: INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER
          launch_stage: BETA
          deletion_protection: false
          deletion_policy: ABANDON
          custom_audiences: [https://api.example.com]
          default_uri_disabled: true
          invoker_iam_disabled: false
          iap_enabled: true
          binary_authorization: { policy: projects/test-project/platforms/cloudRun/policies/p, breakglass_justification: incident }
          scaling: { scaling_mode: MANUAL, manual_instance_count: 3 }
          template:
            containers: [{ image: app }]
    EOT
  }

  assert {
    condition = (
      module.service["api"].service.description == "The API." &&
      module.service["api"].service.annotations == tomap({ team = "core" }) &&
      module.service["api"].service.client == "terraform" &&
      module.service["api"].service.client_version == "1.9" &&
      module.service["api"].service.ingress == "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" &&
      module.service["api"].service.launch_stage == "BETA"
    )
    error_message = "Wrong service-level attributes."
  }
  assert {
    condition = (
      module.service["api"].service.deletion_protection == false &&
      module.service["api"].service.deletion_policy == "ABANDON" &&
      module.service["api"].service.custom_audiences == tolist(["https://api.example.com"]) &&
      module.service["api"].service.default_uri_disabled == true &&
      module.service["api"].service.invoker_iam_disabled == false &&
      module.service["api"].service.iap_enabled == true
    )
    error_message = "Wrong protection, audiences, URI, IAM or IAP settings."
  }
  assert {
    condition = (
      module.service["api"].service.binary_authorization[0].policy == "projects/test-project/platforms/cloudRun/policies/p" &&
      module.service["api"].service.binary_authorization[0].breakglass_justification == "incident"
    )
    error_message = "Wrong Binary Authorization."
  }
  assert {
    condition     = module.service["api"].service.scaling[0].scaling_mode == "MANUAL" && module.service["api"].service.scaling[0].manual_instance_count == 3
    error_message = "Wrong service scaling."
  }
}

run "minimal_service_leaves_settings_to_the_provider" {
  command = plan

  variables {
    config_yaml = <<-EOT
      services:
        tiny:
          template:
            containers: [{ image: app }]
    EOT
  }

  assert {
    condition = (
      module.service["tiny"].service.deletion_protection == null &&
      length(module.service["tiny"].service.binary_authorization) == 0 &&
      length(module.service["tiny"].service.template[0].vpc_access) == 0 &&
      length(module.service["tiny"].service.template[0].containers[0].env) == 0 &&
      length(module.service["tiny"].service.template[0].volumes) == 0 &&
      length(module.service["tiny"].service.traffic) == 0
    )
    error_message = "Unset keys must stay unset (deletion_protection null keeps the provider default)."
  }
}

run "template_settings" {
  command = plan

  variables {
    config_yaml = <<-EOT
      services:
        api:
          template:
            revision: api-v7
            labels: { release: v7 }
            annotations: { note: x }
            timeout: 120s
            service_account: run@test-project.iam.gserviceaccount.com
            execution_environment: EXECUTION_ENVIRONMENT_GEN1
            encryption_key: projects/test-project/locations/europe-west1/keyRings/r/cryptoKeys/k
            max_instance_request_concurrency: 40
            session_affinity: true
            health_check_disabled: true
            scaling: { min_instance_count: 2, max_instance_count: 9 }
            vpc_access: { connector: projects/test-project/locations/europe-west1/connectors/c, egress: ALL_TRAFFIC }
            containers: [{ image: app }]
    EOT
  }

  assert {
    condition = (
      module.service["api"].service.template[0].revision == "api-v7" &&
      module.service["api"].service.template[0].labels == tomap({ release = "v7" }) &&
      module.service["api"].service.template[0].annotations == tomap({ note = "x" }) &&
      module.service["api"].service.template[0].timeout == "120s" &&
      module.service["api"].service.template[0].service_account == "run@test-project.iam.gserviceaccount.com" &&
      module.service["api"].service.template[0].execution_environment == "EXECUTION_ENVIRONMENT_GEN1"
    )
    error_message = "Wrong revision attributes."
  }
  assert {
    condition = (
      module.service["api"].service.template[0].encryption_key == "projects/test-project/locations/europe-west1/keyRings/r/cryptoKeys/k" &&
      module.service["api"].service.template[0].max_instance_request_concurrency == 40 &&
      module.service["api"].service.template[0].session_affinity == true &&
      module.service["api"].service.template[0].health_check_disabled == true &&
      module.service["api"].service.template[0].scaling[0].min_instance_count == 2 &&
      module.service["api"].service.template[0].scaling[0].max_instance_count == 9
    )
    error_message = "Wrong encryption, concurrency, affinity, health check or scaling."
  }
  assert {
    condition = (
      module.service["api"].service.template[0].vpc_access[0].connector == "projects/test-project/locations/europe-west1/connectors/c" &&
      module.service["api"].service.template[0].vpc_access[0].egress == "ALL_TRAFFIC"
    )
    error_message = "Wrong VPC connector."
  }
}

run "direct_vpc_egress_and_gpu" {
  command = plan

  variables {
    config_yaml = <<-EOT
      services:
        gpu:
          template:
            gpu_zonal_redundancy_disabled: true
            node_selector: { accelerator: nvidia-l4 }
            vpc_access:
              network_interfaces:
                - { network: vpc, subnetwork: subnet, tags: [a, b] }
              egress: PRIVATE_RANGES_ONLY
            containers:
              - image: model
                resources:
                  limits: { cpu: "8", memory: 32Gi, nvidia.com/gpu: "1" }
                  cpu_idle: false
    EOT
  }

  assert {
    condition = (
      module.service["gpu"].service.template[0].node_selector[0].accelerator == "nvidia-l4" &&
      module.service["gpu"].service.template[0].gpu_zonal_redundancy_disabled == true &&
      module.service["gpu"].service.template[0].containers[0].resources[0].limits["nvidia.com/gpu"] == "1" &&
      module.service["gpu"].service.template[0].containers[0].resources[0].cpu_idle == false
    )
    error_message = "Wrong GPU settings."
  }
  assert {
    condition     = jsonencode(module.service["gpu"].service.template[0].vpc_access[0].network_interfaces) == jsonencode([{ network = "vpc", subnetwork = "subnet", tags = ["a", "b"] }])
    error_message = "Wrong network interfaces: ${jsonencode(module.service["gpu"].service.template[0].vpc_access[0].network_interfaces)}"
  }
}

run "containers_env_ports_resources_and_mounts" {
  command = plan

  variables {
    config_yaml = <<-EOT
      services:
        web:
          template:
            containers:
              - name: proxy
                image: nginx
                ports: { container_port: 8080, name: h2c }
                depends_on: [app]
                volume_mounts:
                  - { name: cache, mount_path: /cache, sub_path: proxy }
              - name: app
                image: app
                base_image_uri: base
                command: [node]
                args: [server.js]
                working_dir: /srv
                env: { PORT: 9000, DEBUG: false }
                secret_env:
                  TOKEN: { secret: token }
                  KEY: { secret: projects/other/secrets/key, version: "4" }
                resources:
                  limits: { cpu: "2", memory: 1Gi }
                  cpu_idle: true
                  startup_cpu_boost: true
            volumes:
              - name: cache
                empty_dir: { medium: MEMORY, size_limit: 64Mi }
    EOT
  }

  assert {
    condition = (
      module.service["web"].service.template[0].containers[0].name == "proxy" &&
      module.service["web"].service.template[0].containers[0].ports[0].container_port == 8080 &&
      module.service["web"].service.template[0].containers[0].ports[0].name == "h2c" &&
      module.service["web"].service.template[0].containers[0].depends_on == tolist(["app"])
    )
    error_message = "Wrong ingress container."
  }
  assert {
    condition     = jsonencode(module.service["web"].service.template[0].containers[0].volume_mounts) == jsonencode([{ mount_path = "/cache", name = "cache", sub_path = "proxy" }])
    error_message = "Wrong volume mounts: ${jsonencode(module.service["web"].service.template[0].containers[0].volume_mounts)}"
  }
  assert {
    condition = (
      module.service["web"].service.template[0].containers[1].base_image_uri == "base" &&
      module.service["web"].service.template[0].containers[1].command == tolist(["node"]) &&
      module.service["web"].service.template[0].containers[1].args == tolist(["server.js"]) &&
      module.service["web"].service.template[0].containers[1].working_dir == "/srv"
    )
    error_message = "Wrong command, args, working_dir or base image."
  }
  assert {
    condition = toset([
      for e in module.service["web"].service.template[0].containers[1].env :
      e.value != null ? "${e.name}=${e.value}" : "${e.name}=secret:${e.value_source[0].secret_key_ref[0].secret}@${e.value_source[0].secret_key_ref[0].version}"
      ]) == toset([
      "PORT=9000", "DEBUG=false", "TOKEN=secret:token@latest", "KEY=secret:projects/other/secrets/key@4",
    ])
    error_message = "Unexpected env: ${jsonencode(module.service["web"].service.template[0].containers[1].env)}"
  }
  assert {
    condition = (
      module.service["web"].service.template[0].containers[1].resources[0].limits == tomap({ cpu = "2", memory = "1Gi" }) &&
      module.service["web"].service.template[0].containers[1].resources[0].cpu_idle == true &&
      module.service["web"].service.template[0].containers[1].resources[0].startup_cpu_boost == true
    )
    error_message = "Wrong resources."
  }
  assert {
    condition     = module.service["web"].service.template[0].volumes[0].empty_dir[0].medium == "MEMORY" && module.service["web"].service.template[0].volumes[0].empty_dir[0].size_limit == "64Mi"
    error_message = "Wrong empty_dir volume."
  }
}

run "probes" {
  command = plan

  variables {
    config_yaml = <<-EOT
      services:
        probed:
          template:
            containers:
              - image: app
                startup_probe:
                  initial_delay_seconds: 1
                  timeout_seconds: 2
                  period_seconds: 3
                  failure_threshold: 4
                  tcp_socket: { port: 9000 }
                liveness_probe:
                  period_seconds: 30
                  http_get:
                    path: /live
                    port: 9000
                    http_headers:
                      - { name: X-Probe, value: live }
                      - { name: X-Empty }
                readiness_probe:
                  success_threshold: 2
                  failure_threshold: 3
                  period_seconds: 5
                  timeout_seconds: 1
                  http_get: { path: /ready }
        grpc:
          template:
            containers:
              - image: app
                ports: { container_port: 50051, name: h2c }
                startup_probe:
                  grpc: { port: 50051, service: health }
                readiness_probe:
                  grpc: { service: ready }
    EOT
  }

  assert {
    condition = (
      module.service["probed"].service.template[0].containers[0].startup_probe[0].initial_delay_seconds == 1 &&
      module.service["probed"].service.template[0].containers[0].startup_probe[0].timeout_seconds == 2 &&
      module.service["probed"].service.template[0].containers[0].startup_probe[0].period_seconds == 3 &&
      module.service["probed"].service.template[0].containers[0].startup_probe[0].failure_threshold == 4 &&
      module.service["probed"].service.template[0].containers[0].startup_probe[0].tcp_socket[0].port == 9000
    )
    error_message = "Wrong startup probe."
  }
  assert {
    condition = (
      module.service["probed"].service.template[0].containers[0].liveness_probe[0].http_get[0].path == "/live" &&
      jsonencode(module.service["probed"].service.template[0].containers[0].liveness_probe[0].http_get[0].http_headers) == jsonencode([{ name = "X-Probe", value = "live" }, { name = "X-Empty", value = null }])
    )
    error_message = "Wrong liveness probe: ${jsonencode(module.service["probed"].service.template[0].containers[0].liveness_probe)}"
  }
  assert {
    condition = (
      module.service["probed"].service.template[0].containers[0].readiness_probe[0].success_threshold == 2 &&
      module.service["probed"].service.template[0].containers[0].readiness_probe[0].http_get[0].path == "/ready"
    )
    error_message = "Wrong readiness probe."
  }
  assert {
    condition = (
      module.service["grpc"].service.template[0].containers[0].startup_probe[0].grpc[0].service == "health" &&
      module.service["grpc"].service.template[0].containers[0].readiness_probe[0].grpc[0].service == "ready"
    )
    error_message = "Wrong gRPC probes."
  }
}

run "volumes_and_secret_modes" {
  command = plan

  variables {
    config_yaml = <<-EOT
      services:
        vols:
          template:
            containers: [{ image: app }]
            volumes:
              - name: octal
                secret:
                  secret: s
                  default_mode: "0444"
                  items:
                    - { path: a, version: "1", mode: "0400" }
                    - { path: b }
              - name: decimal
                secret: { secret: s, default_mode: 292 }
              - name: sql
                cloud_sql_instance: { instances: ["p:r:i1", "p:r:i2"] }
              - name: bucket
                gcs: { bucket: b, read_only: true, mount_options: [implicit-dirs] }
              - name: share
                nfs: { server: 10.0.0.2, path: /share, read_only: true }
    EOT
  }

  assert {
    condition = (
      module.service["vols"].service.template[0].volumes[0].secret[0].default_mode == 292 &&
      module.service["vols"].service.template[0].volumes[0].secret[0].items[0].mode == 256 &&
      module.service["vols"].service.template[0].volumes[0].secret[0].items[0].version == "1" &&
      module.service["vols"].service.template[0].volumes[0].secret[0].items[1].mode == null
    )
    error_message = "Quoted octal modes should become numbers: ${jsonencode(module.service["vols"].service.template[0].volumes[0].secret)}"
  }
  assert {
    condition     = module.service["vols"].service.template[0].volumes[1].secret[0].default_mode == 292
    error_message = "Decimal modes should be kept."
  }
  assert {
    condition     = module.service["vols"].service.template[0].volumes[2].cloud_sql_instance[0].instances == toset(["p:r:i1", "p:r:i2"])
    error_message = "Wrong Cloud SQL volume."
  }
  assert {
    condition = (
      module.service["vols"].service.template[0].volumes[3].gcs[0].bucket == "b" &&
      module.service["vols"].service.template[0].volumes[3].gcs[0].read_only == true &&
      module.service["vols"].service.template[0].volumes[3].gcs[0].mount_options == tolist(["implicit-dirs"])
    )
    error_message = "Wrong Cloud Storage volume."
  }
  assert {
    condition = (
      module.service["vols"].service.template[0].volumes[4].nfs[0].server == "10.0.0.2" &&
      module.service["vols"].service.template[0].volumes[4].nfs[0].path == "/share" &&
      module.service["vols"].service.template[0].volumes[4].nfs[0].read_only == true
    )
    error_message = "Wrong NFS volume."
  }
}

run "traffic_short_and_long_forms" {
  command = plan

  variables {
    config_yaml = <<-EOT
      services:
        split:
          template:
            revision: split-v2
            containers: [{ image: app }]
          traffic:
            - { type: REVISION, revision: split-v1, percent: 80, tag: stable }
            - { type: LATEST, percent: 15 }
            - { type: TRAFFIC_TARGET_ALLOCATION_TYPE_REVISION, revision: split-v2, percent: 5, tag: canary }
    EOT
  }

  assert {
    condition = [for t in module.service["split"].service.traffic : "${t.type}|${coalesce(t.revision, "-")}|${t.percent}|${coalesce(t.tag, "-")}"] == [
      "TRAFFIC_TARGET_ALLOCATION_TYPE_REVISION|split-v1|80|stable",
      "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST|-|15|-",
      "TRAFFIC_TARGET_ALLOCATION_TYPE_REVISION|split-v2|5|canary",
    ]
    error_message = "Unexpected traffic: ${jsonencode(module.service["split"].service.traffic)}"
  }
}
