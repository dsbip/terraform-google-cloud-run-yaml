# Validation: each run plants several mistakes and compares the complete set
# of messages, so a missing message and a spurious extra one both fail.

mock_provider "google" {}

variables {
  project_id = "test-project"
  region     = "europe-west1"
}

run "schema_checks_keys_types_enums_patterns_ranges_and_required_keys" {
  command = plan

  variables {
    config_yaml = <<-EOT
      service:
        x: {}
      defaults:
        service_containers: {}
        services:
          ingres: x
      services:
        api:
          descripton: typo
          ingress: PUBLIC
          deletion_protection: maybe
          scaling: { scaling_mode: AUTO, min_instance_count: -1 }
          template:
            timeout: 30
            max_instance_request_concurrency: 0
            execution_environment: GEN2
            containers:
              - image: app
                imgae: typo
                ports: { container_port: 70000, name: http2 }
                env: { A: [list] }
                secret_env:
                  S: { secrets: typo }
                resources: { limit: {} }
                liveness_probe:
                  http_get: { path: /x, headers: [] }
                  period_seconds: 0
            volumes:
              - name: v
                secret: { secret: s, default_mode: 1000, items: [{ version: "1" }] }
              - secret: { secret: s }
          traffic:
            - { type: NEWEST, percent: 101 }
          invokers: [bob@example.com]
          schedules:
            nightly:
              path: tasks
              http_method: FETCH
              attempt_deadline: 5m
      jobs:
        etl:
          template:
            task_count: 0
            max_retries: 11
            containers:
              - image: app
                liveness_probe: {}
                ports: { container_port: 80 }
          schedules:
            s:
              schedule: "0 * * * *"
              overrides: { task_count: 0, args: x, extra: 1 }
    EOT
  }

  expect_failures = [terraform_data.validation]

  assert {
    condition = toset(local.validation_errors) == toset([
      "services.api: unknown key \"descripton\" (did you mean description?)",
      "(root): unknown key \"service\" (did you mean services?)",
      "defaults: unknown key \"service_containers\" (did you mean service_container or services?)",
      "defaults.services: unknown key \"ingres\" (did you mean ingress?)",
      "jobs.etl.schedules.s.overrides: unknown key \"extra\"",
      "jobs.etl.template.containers[0]: unknown key \"liveness_probe\" (did you mean startup_probe?)",
      "jobs.etl.template.containers[0]: unknown key \"ports\"",
      "services.api.template.containers[0]: unknown key \"imgae\" (did you mean image?)",
      "services.api.template.containers[0].resources: unknown key \"limit\" (did you mean limits?)",
      "services.api.template.containers[0].secret_env.S: unknown key \"secrets\" (did you mean secret?)",
      "services.api.template.containers[0].liveness_probe.http_get: unknown key \"headers\" (did you mean http_headers?)",
      "services.api.deletion_protection: must be true or false",
      "jobs.etl.schedules.s.overrides.args: must be a list",
      "services.api.template.containers[0].env.A: must be a string",
      "services.api.ingress: must be one of INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY, INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER (got \"PUBLIC\")",
      "services.api.scaling.scaling_mode: must be one of AUTOMATIC, MANUAL (got \"AUTO\")",
      "services.api.schedules.nightly.http_method: must be one of POST, GET, HEAD, PUT, DELETE, PATCH, OPTIONS (got \"FETCH\")",
      "services.api.template.execution_environment: must be one of EXECUTION_ENVIRONMENT_GEN1, EXECUTION_ENVIRONMENT_GEN2 (got \"GEN2\")",
      "services.api.traffic[0].type: must be one of LATEST, REVISION, TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST, TRAFFIC_TARGET_ALLOCATION_TYPE_REVISION (got \"NEWEST\")",
      "services.api.template.containers[0].ports.name: must be one of http1, h2c (got \"http2\")",
      "services.api.schedules.nightly.attempt_deadline: \"5m\" is not valid (Deadline per attempt, e.g. 320s)",
      "services.api.schedules.nightly.path: \"tasks\" is not valid (Path to call, e.g. /tasks/cleanup (default /))",
      "services.api.template.timeout: \"30\" is not valid (Request timeout, e.g. 300s (up to 3600s))",
      "services.api.invokers[0]: \"bob@example.com\" is not valid (IAM member: user:, group:, serviceAccount:, domain:, principal://, principalSet://, allUsers or allAuthenticatedUsers)",
      "jobs.etl.template.task_count: must be at least 1",
      "services.api.scaling.min_instance_count: must be at least 0",
      "services.api.template.max_instance_request_concurrency: must be at least 1",
      "jobs.etl.schedules.s.overrides.task_count: must be at least 1",
      "services.api.template.containers[0].liveness_probe.period_seconds: must be at least 1",
      "jobs.etl.template.max_retries: must be at most 10",
      "services.api.traffic[0].percent: must be at most 100",
      "services.api.template.containers[0].ports.container_port: must be at most 65535",
      "services.api.template.volumes[0].secret.default_mode: must be at most 511",
      "services.api.schedules.nightly: missing required key \"schedule\"",
      "services.api.template.volumes[1]: missing required key \"name\"",
      "services.api.template.containers[0].secret_env.S: missing required key \"secret\"",
      "services.api.template.volumes[0].secret.items[0]: missing required key \"path\"",
      "jobs.etl.schedules.s: service_account_email is required (it needs roles/run.invoker: add it to invokers)",
      "services.api.traffic: the percentages add up to 101, not 100",
      "services.api.schedules.nightly: service_account_email is required (it needs roles/run.invoker: add it to invokers)",
    ])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
  assert {
    condition     = length(module.service) == 0 && length(module.job) == 0
    error_message = "Nothing may be planned while the configuration is invalid."
  }
}

run "rules_beyond_the_schema" {
  command = plan

  variables {
    project_id  = null
    region      = null
    config_yaml = <<-EOT
      defaults:
        services:
          name: shared
        job_container:
          name: x
      services:
        Bad_Key: {}
        no-containers:
          project_id: p
          region: r
          template: {}
        multi:
          project_id: p
          region: r
          template:
            execution_environment: EXECUTION_ENVIRONMENT_GEN1
            node_selector: { accelerator: nvidia-l4 }
            vpc_access: { connector: c, network_interfaces: [{ subnetwork: s }] }
            scaling: { min_instance_count: 5, max_instance_count: 2 }
            containers:
              - name: a
                ports: { container_port: 8080 }
                depends_on: [ghost]
                env: { DUP: "1" }
                secret_env: { DUP: { secret: s } }
                volume_mounts: [{ name: missing, mount_path: /m }]
                liveness_probe: { http_get: {}, tcp_socket: {} }
              - name: a
                image: b
                ports: { container_port: 9090 }
              - image: c
            volumes:
              - { name: v, gcs: { bucket: b }, nfs: { server: s } }
              - { name: v, empty_dir: {} }
              - name: modes
                secret: { secret: s, default_mode: 444, items: [{ path: p, mode: 600 }] }
          binary_authorization: { use_default: true, policy: p }
          scaling: { scaling_mode: MANUAL, min_instance_count: 3, max_instance_count: 1 }
          traffic:
            - { type: REVISION, percent: 50 }
            - { type: LATEST, revision: r, percent: 30 }
          schedules:
            nosa: { schedule: "0 * * * *" }
        egress-only:
          project_id: p
          region: r
          template:
            vpc_access: { egress: ALL_TRAFFIC }
            containers: [{ image: x }]
        dup-a: { name: same, project_id: p, region: r, template: { containers: [{ image: x }] } }
        dup-b: { name: same, project_id: p, region: r, template: { containers: [{ image: x }] } }
      jobs:
        both-tokens:
          project_id: p
          region: r
          start_execution_token: a
          run_execution_token: b
          template:
            containers: [{ name: main, image: x }]
          schedules:
            s:
              schedule: "0 * * * *"
              service_account_email: a@b.c
              overrides: { container: ghost }
        on:
          project_id: p
          region: r
          template: { containers: [{ image: x }] }
    EOT
  }

  expect_failures = [terraform_data.validation]

  # `on` became "true"; the module reports it.
  assert {
    condition = toset(local.validation_errors) == toset([
      "defaults.job_container: \"name\" cannot be a default",
      "defaults.services: \"name\" cannot be a default",
      "services.multi.template.volumes[2].secret.items[0].mode: must be at most 511",
      "jobs.both-tokens: set start_execution_token or run_execution_token, not both",
      "jobs.both-tokens.schedules.s.overrides.container: no container is named \"ghost\"",
      "jobs.true: YAML reads unquoted yes, no, on, off, true and false as booleans; quote the key (e.g. \"on\":) or choose another name",
      "services.Bad_Key: no project_id; set it here, at the top level of the file, or in the module's project_id variable",
      "services.Bad_Key: no region; set it here, in defaults.region, or in the module's region variable",
      "services.Bad_Key: the key is used as the name but is not a valid one (lowercase letters, digits and hyphens, starting with a letter, at most 49 characters); rename it or set name",
      "services.Bad_Key: template (with containers) is required, here or in defaults.services",
      "services.egress-only.template.vpc_access: egress needs connector or network_interfaces",
      "services.multi.template.volumes: the name \"v\" is used 2 times",
      "services.multi.template.volumes[0]: set exactly one of secret, cloud_sql_instance, empty_dir, gcs and nfs",
      "services.multi.template.volumes[2].secret.default_mode: 444 looks like an octal mode written as a decimal number (YAML reads unquoted 0444 as 444); write \"0444\" in quotes, or the decimal 292",
      "services.multi.template.volumes[2].secret.items[0].mode: 600 looks like an octal mode written as a decimal number (YAML reads unquoted 0600 as 600); write \"0600\" in quotes, or the decimal 384",
      "services.multi.template: Cloud Storage and NFS volumes need execution_environment EXECUTION_ENVIRONMENT_GEN2",
      "services.multi.template.containers: with several containers, every container needs a name",
      "services.multi.template.containers: the name \"a\" is used 2 times",
      "services.multi.template.containers: with several containers, exactly one (the ingress container) must set ports",
      "services.multi.template.containers[0]: image is required, here or in defaults.service_container",
      "services.multi.template.containers[0].depends_on: no container is named \"ghost\"",
      "services.multi.template.containers[0].volume_mounts[0]: no volume is named \"missing\"",
      "services.multi.template.containers[0]: DUP is set in both env and secret_env",
      "services.multi.template.containers[0].liveness_probe: set only one of http_get, tcp_socket and grpc",
      "services.multi.template.node_selector: a GPU needs resources.limits[\"nvidia.com/gpu\"] on a container",
      "services.multi.binary_authorization: set use_default or policy, not both",
      "services.multi.template.vpc_access: use connector or network_interfaces, not both",
      "services.multi.template.scaling: min_instance_count (5) is greater than max_instance_count (2)",
      "services.multi.scaling: min_instance_count (3) is greater than max_instance_count (1)",
      "services.multi.scaling: scaling_mode MANUAL needs manual_instance_count",
      "services.multi.traffic: the percentages add up to 80, not 100",
      "services.multi.traffic[0]: type REVISION needs revision",
      "services.multi.traffic[1]: revision is only allowed with type REVISION",
      "services.multi.schedules.nosa: service_account_email is required (it needs roles/run.invoker: add it to invokers)",
      "services.no-containers.template: containers is required",
      "services: dup-a, dup-b would all create service p/r/same",
    ])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}

run "the_document_and_its_sections_must_be_mappings" {
  command = plan

  variables {
    config_yaml = "[services, jobs]"
  }

  expect_failures = [terraform_data.validation]

  assert {
    condition     = local.validation_errors == tolist(["(root): the configuration must be a mapping (key: value pairs)"])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}

run "sections_and_entries_with_the_wrong_type" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults: [region]
      services:
        api: just a string
      jobs: [etl]
    EOT
  }

  expect_failures = [terraform_data.validation]

  assert {
    condition = toset(local.validation_errors) == toset([
      "defaults: must be a mapping",
      "services.api: must be a mapping",
      "jobs: must be a mapping",
    ])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}

run "config_file_and_config_yaml_are_exclusive" {
  command = plan

  variables {
    config_file = "tests/fixtures/blank.yaml"
    config_yaml = "services: {}"
  }

  expect_failures = [terraform_data.validation]

  assert {
    condition     = local.validation_errors == tolist(["(module): set config_file or config_yaml, not both"])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}

run "one_of_config_file_and_config_yaml_is_required" {
  command = plan

  expect_failures = [terraform_data.validation]

  assert {
    condition     = local.validation_errors == tolist(["(module): set config_file or config_yaml"])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}

run "config_file_must_exist" {
  command = plan

  variables {
    config_file = "tests/fixtures/missing.yaml"
  }

  expect_failures = [var.config_file]
}

run "a_valid_file_has_no_messages" {
  command = plan

  variables {
    config_file   = "tests/fixtures/templated.yaml"
    template_vars = { env = "prod", tag = "1.0" }
  }

  assert {
    condition     = length(local.validation_errors) == 0 && local.config_valid
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}

run "the_deepest_level_of_defaults_is_checked" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        services:
          template:
            containers:
              - image: x
                liveness_probe:
                  http_get:
                    http_headers:
                      - { nam: X-Probe }
    EOT
  }

  expect_failures = [terraform_data.validation]

  assert {
    condition = toset(local.validation_errors) == toset([
      "defaults.services.template.containers[0].liveness_probe.http_get.http_headers[0]: unknown key \"nam\" (did you mean name?)",
      "defaults.services.template.containers[0].liveness_probe.http_get.http_headers[0]: missing required key \"name\"",
    ])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}
