# Loading the configuration: files, inline YAML, templating, precedence of
# projects, regions and labels, the defaults merges, enabled, names.

mock_provider "google" {}

variables {
  project_id = "test-project"
  region     = "europe-west1"
}

run "config_file_is_rendered_with_template_vars" {
  command = plan

  variables {
    config_file   = "tests/fixtures/templated.yaml"
    template_vars = { env = "dev", tag = "1.0" }
  }

  assert {
    condition     = toset(keys(module.service)) == toset(["api-dev"]) && toset(keys(module.job)) == toset(["batch-dev"])
    error_message = "Expected api-dev and batch-dev only: ${jsonencode(keys(module.service))}"
  }
  assert {
    condition     = module.service["api-dev"].service.description == "API 1.0 in test-project"
    error_message = "template_vars and project_id were not substituted."
  }
  assert {
    condition     = module.service["api-dev"].service.template[0].containers[0].image == "europe-docker.pkg.dev/test-project/app/api:1.0"
    error_message = "The image was not rendered."
  }
  assert {
    condition     = module.service["api-dev"].region == "europe-west1" && module.service["api-dev"].service.labels == tomap({ environment = "dev" })
    error_message = "defaults.region and defaults.labels were not applied."
  }
  assert {
    condition     = length(module.service["api-dev"].service.template[0].scaling) == 0
    error_message = "The %%{ if } block must not render in dev."
  }
  assert {
    condition     = module.job["batch-dev"].job.template[0].task_count == 1
    error_message = "Expressions in placeholders should render."
  }
}

run "template_directives_and_enabled_follow_the_variables" {
  command = plan

  variables {
    config_file   = "tests/fixtures/templated.yaml"
    template_vars = { env = "prod", tag = "2.0" }
  }

  assert {
    condition     = toset(keys(module.service)) == toset(["api-prod", "literal"])
    error_message = "Expected api-prod and literal in prod."
  }
  assert {
    condition     = module.service["api-prod"].service.template[0].scaling[0].min_instance_count == 2
    error_message = "The %%{ if } block should render in prod."
  }
  assert {
    condition     = module.service["literal"].service.description == "Costs $${price}"
    error_message = "$$${ in the file must produce a literal $${."
  }
  assert {
    condition     = module.job["batch-prod"].job.template[0].task_count == 10
    error_message = "task_count should be 10 in prod."
  }
}

run "config_yaml_is_used_verbatim" {
  command = plan

  variables {
    config_yaml = <<-EOT
      services:
        hello:
          description: "Uses $${literal} placeholders"
          template:
            containers: [{ image: hello }]
    EOT
  }

  assert {
    condition     = module.service["hello"].service.description == "Uses $${literal} placeholders"
    error_message = "config_yaml must not be template-rendered."
  }
}

run "yamlencode_output_works_as_config_yaml" {
  command = plan

  variables {
    config_yaml = yamlencode({
      jobs = { task = { template = { containers = [{ image = "job" }] } } }
    })
  }

  assert {
    condition     = module.job["task"].job.template[0].template[0].containers[0].image == "job"
    error_message = "yamlencode() output was not accepted."
  }
}

run "blank_or_comment_only_file_creates_nothing" {
  command = plan

  variables {
    config_file = "tests/fixtures/blank.yaml"
  }

  assert {
    condition     = length(module.service) == 0 && length(module.job) == 0 && length(local.validation_errors) == 0
    error_message = "A comment-only file should be valid and create nothing."
  }
}

run "project_and_region_precedence" {
  command = plan

  variables {
    project_id  = "var-project"
    region      = "var-region"
    config_yaml = <<-EOT
      project_id: yaml-project
      defaults:
        region: defaults-region
        jobs:
          region: jobs-region
      services:
        from-file:
          template: { containers: [{ image: a }] }
        own:
          project_id: own-project
          region: own-region
          template: { containers: [{ image: a }] }
      jobs:
        from-jobs-defaults:
          template: { containers: [{ image: a }] }
    EOT
  }

  assert {
    condition     = module.service["from-file"].project_id == "yaml-project" && module.service["from-file"].region == "defaults-region"
    error_message = "The top-level project_id and defaults.region should override the variables."
  }
  assert {
    condition     = module.service["own"].project_id == "own-project" && module.service["own"].region == "own-region"
    error_message = "An entry's own project_id and region should win."
  }
  assert {
    condition     = module.job["from-jobs-defaults"].region == "jobs-region"
    error_message = "defaults.jobs.region should override defaults.region."
  }
}

run "variables_are_the_last_fallback" {
  command = plan

  variables {
    project_id  = "var-project"
    region      = "var-region"
    config_yaml = <<-EOT
      jobs:
        j:
          template: { containers: [{ image: a }] }
    EOT
  }

  assert {
    condition     = module.job["j"].project_id == "var-project" && module.job["j"].region == "var-region"
    error_message = "Without YAML values, the variables should be used."
  }
}

run "labels_are_merged_in_order" {
  command = plan

  variables {
    labels      = { managed-by = "terraform", layer = "var" }
    config_yaml = <<-EOT
      defaults:
        labels: { layer: defaults, team: core, version: 3 }
        services:
          labels: { layer: defaults-services, tier: standard }
      services:
        api:
          labels: { tier: critical, canary: true }
          template: { containers: [{ image: a }] }
      jobs:
        j:
          template: { containers: [{ image: a }] }
    EOT
  }

  assert {
    condition = module.service["api"].service.labels == tomap({
      managed-by = "terraform", layer = "defaults-services", team = "core", version = "3", tier = "critical", canary = "true"
    })
    error_message = "Unexpected service labels: ${jsonencode(module.service["api"].service.labels)}"
  }
  assert {
    condition     = module.job["j"].job.labels == tomap({ managed-by = "terraform", layer = "defaults", team = "core", version = "3" })
    error_message = "defaults.services.labels must not reach jobs: ${jsonencode(module.job["j"].job.labels)}"
  }
}

run "entry_defaults_merge_three_levels_deep" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        services:
          description: default description
          ingress: INGRESS_TRAFFIC_INTERNAL_ONLY
          template:
            service_account: default@test-project.iam.gserviceaccount.com
            timeout: 30s
            scaling: { min_instance_count: 1, max_instance_count: 5 }
            containers: [{ image: default-image }]
          invokers: [allUsers]
      services:
        api:
          ingress: INGRESS_TRAFFIC_ALL                 # level 1 override
          template:
            timeout: 60s                               # level 2 override
            scaling: { max_instance_count: 50 }        # level 3 merge
            containers: [{ image: own-image }]         # lists replace
          invokers: [group:devs@example.com]           # lists replace
        inherits-all: {}
    EOT
  }

  assert {
    condition     = module.service["api"].service.description == "default description" && module.service["api"].service.ingress == "INGRESS_TRAFFIC_ALL"
    error_message = "Level 1: description from defaults, ingress from the service."
  }
  assert {
    condition = (
      module.service["api"].service.template[0].service_account == "default@test-project.iam.gserviceaccount.com" &&
      module.service["api"].service.template[0].timeout == "60s"
    )
    error_message = "Level 2: service_account from defaults, timeout from the service."
  }
  assert {
    condition = (
      module.service["api"].service.template[0].scaling[0].min_instance_count == 1 &&
      module.service["api"].service.template[0].scaling[0].max_instance_count == 50
    )
    error_message = "Level 3: scaling keys should merge."
  }
  assert {
    condition     = length(module.service["api"].service.template[0].containers) == 1 && module.service["api"].service.template[0].containers[0].image == "own-image"
    error_message = "containers must replace the default list."
  }
  assert {
    condition     = module.service["api"].invoker_members == tolist(["group:devs@example.com"]) && module.service["inherits-all"].invoker_members == tolist(["allUsers"])
    error_message = "invokers must replace the default list."
  }
  assert {
    condition     = module.service["inherits-all"].service.template[0].containers[0].image == "default-image"
    error_message = "An empty entry should take everything from defaults."
  }
}

run "container_defaults_merge_into_every_container" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        service_container:
          resources:
            limits: { cpu: "1", memory: 512Mi }
            startup_cpu_boost: true
          env: { LOG_LEVEL: info, REGION: eu }
          secret_env:
            SHARED: { secret: shared }
        job_container:
          image: default-job-image
          env: { JOB: "yes" }
      services:
        api:
          template:
            containers:
              - name: app
                image: app
                ports: { container_port: 8080 }
                resources:
                  limits: { memory: 2Gi }               # level 3: cpu stays 1
                env: { LOG_LEVEL: debug }               # level 2: REGION stays
              - name: sidecar
                image: sidecar
      jobs:
        j:
          template:
            containers:
              - args: [run]                             # image from defaults
    EOT
  }

  assert {
    condition     = module.service["api"].service.template[0].containers[0].resources[0].limits == tomap({ cpu = "1", memory = "2Gi" })
    error_message = "Level 3: limits should merge: ${jsonencode(module.service["api"].service.template[0].containers[0].resources[0].limits)}"
  }
  assert {
    condition     = module.service["api"].service.template[0].containers[0].resources[0].startup_cpu_boost == true
    error_message = "Level 2: startup_cpu_boost should come from defaults."
  }
  assert {
    condition = toset([for e in module.service["api"].service.template[0].containers[0].env : "${e.name}=${coalesce(e.value, "<secret>")}"]) == toset([
      "LOG_LEVEL=debug", "REGION=eu", "SHARED=<secret>",
    ])
    error_message = "env and secret_env should merge with the defaults: ${jsonencode(module.service["api"].service.template[0].containers[0].env)}"
  }
  assert {
    condition     = module.service["api"].service.template[0].containers[1].resources[0].limits == tomap({ cpu = "1", memory = "512Mi" })
    error_message = "Every container (also sidecars) gets the container defaults."
  }
  assert {
    condition     = module.job["j"].job.template[0].template[0].containers[0].image == "default-job-image"
    error_message = "defaults.job_container.image should apply to job containers."
  }
  assert {
    condition     = [for e in module.job["j"].job.template[0].template[0].containers[0].env : e.name] == ["JOB"]
    error_message = "Service container defaults must not reach job containers."
  }
}

run "explicit_nulls_never_override_defaults" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        services:
          description: from defaults
          template:
            timeout: 45s
        service_container:
          env: { A: "1" }
      services:
        api:
          description:
          template:
            timeout:
            containers:
              - image: x
                env:
    EOT
  }

  assert {
    condition     = module.service["api"].service.description == "from defaults" && module.service["api"].service.template[0].timeout == "45s"
    error_message = "Empty keys must not override defaults."
  }
  assert {
    condition     = [for e in module.service["api"].service.template[0].containers[0].env : e.name] == ["A"]
    error_message = "An empty container key must not override the container defaults."
  }
}

run "names_and_enabled" {
  command = plan

  variables {
    config_yaml = <<-EOT
      services:
        from-key:
          template: { containers: [{ image: a }] }
        renamed:
          name: actual-name
          template: { containers: [{ image: a }] }
        disabled:
          enabled: false
          template: { containers: [{ image: a }] }
      jobs:
        disabled-job:
          enabled: "false"
          template: { containers: [{ image: a }] }
    EOT
  }

  assert {
    condition     = toset(keys(module.service)) == toset(["from-key", "renamed"]) && length(module.job) == 0
    error_message = "Disabled entries must not be deployed."
  }
  assert {
    condition     = module.service["from-key"].name == "from-key" && module.service["renamed"].name == "actual-name"
    error_message = "The key is the default name."
  }
  assert {
    condition     = local.services["disabled"].enabled == false && local.jobs["disabled-job"].enabled == false
    error_message = "enabled should accept booleans and strings."
  }
}
