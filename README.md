# terraform-google-cloud-run-yaml

[![CI](https://github.com/dsbip/terraform-google-cloud-run-yaml/actions/workflows/ci.yml/badge.svg)](https://github.com/dsbip/terraform-google-cloud-run-yaml/actions/workflows/ci.yml)

A Terraform module that deploys any number of **Cloud Run services and jobs** from one YAML file:

- **Services**: one or more containers (sidecars with start ordering), ports and HTTP/2, startup/liveness/readiness probes, CPU and memory, always-on CPU, startup boost, GPUs, scaling (per revision and per service, automatic or manual), concurrency, timeouts, session affinity
- **Jobs**: tasks, parallelism, retries, timeouts, GPUs, run-on-deploy with execution tokens
- **Configuration and storage**: environment variables, Secret Manager secrets as variables or files, Cloud SQL, Cloud Storage FUSE, NFS and in-memory volumes
- **Networking and security**: ingress, Serverless VPC Access connectors, Direct VPC egress, CMEK, Binary Authorization, IAP, custom audiences, disabling the default URL
- **Traffic**: named revisions, splits, tags (canary, blue/green)
- **Schedules**: Cloud Scheduler jobs that call a service path (OIDC) or execute a job (with argument, environment, task count and timeout overrides)
- **Access**: invokers (`roles/run.invoker`) and IAM with conditions on services and jobs
- **Defaults** for services, jobs and every container, merged three levels deep, plus `${...}` templating and `%{ if }` blocks for one file across environments

The module catches mistakes before anything reaches Google Cloud. A typo fails the plan with its YAML path and a suggestion, for example `services.api.template.containers[0]: unknown key "imgae" (did you mean image?)`.

```yaml
# cloud-run.yaml
defaults:
  region: europe-west1
  service_container:
    resources:
      limits: { cpu: "1", memory: 512Mi }

services:
  api:
    template:
      containers:
        - image: europe-docker.pkg.dev/my-project/app/api:1.4.2
          env: { LOG_LEVEL: info }
          secret_env:
            DB_PASSWORD: { secret: api-db-password }
      scaling: { min_instance_count: 1, max_instance_count: 20 }
    invokers: [allUsers]

jobs:
  nightly-report:
    template:
      task_count: 10
      containers:
        - image: europe-docker.pkg.dev/my-project/app/report:1.4.2
    invokers: ["serviceAccount:scheduler@my-project.iam.gserviceaccount.com"]
    schedules:
      nightly:
        schedule: "0 2 * * *"
        time_zone: Europe/Berlin
        service_account_email: scheduler@my-project.iam.gserviceaccount.com
```

```hcl
module "cloud_run" {
  source = "github.com/dsbip/terraform-google-cloud-run-yaml?ref=v1.0.0"

  project_id  = "my-project"
  config_file = "${path.module}/cloud-run.yaml"
}
```

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Usage](#usage)
- [Module structure](#module-structure)
- [Inputs](#inputs)
- [Outputs](#outputs)
- [Examples](#examples)
- [Documentation](#documentation)
- [Testing](#testing)

## Features

| Area | What the YAML covers | Docs |
|---|---|---|
| File | `project_id`, `defaults` (region, labels, services, jobs, service and job containers), templating, `enabled` | [configuration.md](docs/configuration.md) |
| Services | ingress, launch stage, deletion protection, Binary Authorization, IAP, audiences, service scaling, traffic | [services.md](docs/services.md) |
| Revisions | containers, volumes, scaling, VPC access, GPUs, timeout, concurrency, service account, CMEK, execution environment | [services.md](docs/services.md#template) |
| Containers | image, command, args, env, secrets, resources, ports, probes, volume mounts, start order | [services.md](docs/services.md#containers) |
| Jobs | tasks, parallelism, retries, timeouts, execution tokens, the same containers and volumes | [jobs.md](docs/jobs.md) |
| Schedules | service calls (OIDC) and job executions (OAuth, overrides) with time zones and retries | [services.md](docs/services.md#schedules), [jobs.md](docs/jobs.md#schedules) |
| Access | invokers, IAM bindings with conditions | [services.md](docs/services.md#invokers-and-iam) |
| Validation | unknown keys, types, enumerations, ranges, patterns, required keys, container/volume references, exclusive options, traffic sums, duplicates: all at once with YAML paths | [configuration.md](docs/configuration.md#validation) |

## Requirements

| | Version |
|---|---|
| Terraform | >= 1.5 (the unit tests need >= 1.7) |
| `hashicorp/google` provider | >= 7.42, < 9.0 |

APIs: Cloud Run Admin; Cloud Scheduler for schedules. Images, service accounts, secrets, connectors, networks and keys referenced in the YAML must already exist.

## Usage

1. Write a YAML file (start from an [example](examples/README.md)). Add this line at the top for autocompletion and validation in editors with the YAML language server:

   ```yaml
   # yaml-language-server: $schema=<path to>/schemas/cloud-run-config.schema.json
   ```

2. Call the module with `config_file` (rendered with `templatefile()`) or `config_yaml` (used as-is):

   ```hcl
   module "cloud_run" {
     source = "github.com/dsbip/terraform-google-cloud-run-yaml?ref=v1.0.0"

     project_id    = var.project_id
     region        = "europe-west1"
     config_file   = "${path.module}/cloud-run.yaml"
     template_vars = { image_tag = var.image_tag, env = "prod" }
     labels        = { managed-by = "terraform" }
   }
   ```

3. `terraform plan`. If the file has problems, the plan fails with all of them:

   ```text
   The Cloud Run YAML configuration has 3 problem(s):
     - services.api.template.containers[0]: unknown key "imgae" (did you mean image?)
     - services.web.template.containers: with several containers, exactly one (the ingress container) must set ports
     - jobs.etl.schedules.nightly: service_account_email is required (it needs roles/run.invoker: add it to invokers)
   ```

Services are protected from deletion by the provider by default (`deletion_protection` defaults to `true`); set `deletion_protection: false` (for example in `defaults.services`) for services that `terraform destroy` may remove. The same applies to jobs.

## Module structure

```text
root module (this directory)        YAML → validated, merged, normalised inputs
  │  main.tf        load + template + defaults merges (entries, then containers)
  │  validation.tf  schema-driven checks + rules, gate for_each
  │  services.tf    module "service" { for_each = services }
  │  jobs.tf        module "job"     { for_each = jobs }
  ▼
modules/service   one service + invokers + IAM ──┐
modules/job       one job + invokers + IAM ──────┤ schedules
  ▼                                              ▼
modules/schedule  one Cloud Scheduler HTTP job (OIDC or OAuth token)
```

- [`modules/service`](modules/service/README.md), [`modules/job`](modules/job/README.md): deploy one service or job from typed HCL inputs, as in [examples/standalone-modules](examples/standalone-modules).
- [`modules/schedule`](modules/schedule/README.md): a Cloud Scheduler HTTP job for any target.
- [`schemas/cloud-run-config.schema.json`](schemas/cloud-run-config.schema.json): the YAML format, used by editors and by `validation.tf`.

See [docs/design.md](docs/design.md) for why it is built this way.

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `config_file` | Path to the YAML file, rendered with `templatefile()`. Exactly one of `config_file` and `config_yaml`. | `string` | `null` |
| `config_yaml` | YAML as a string, used as-is. | `string` | `null` |
| `template_vars` | Values for placeholders in `config_file`. `project_id` and `region` are always available. | `any` | `{}` |
| `project_id` | Default project. The YAML's top-level `project_id` and an entry's own `project_id` take precedence. | `string` | `null` |
| `region` | Default region. `defaults.region` and an entry's own `region` take precedence. | `string` | `null` |
| `labels` | Labels added to every service and job; YAML labels win on conflicts. | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `services` | Per YAML key: `id`, `name`, `project_id`, `region`, `uri`, `urls`, `latest_ready_revision`, `service_account`, `schedules` |
| `jobs` | Per YAML key: `id`, `name`, `project_id`, `region`, `run_uri`, `latest_created_execution`, `service_account`, `schedules` |
| `service_uris` | YAML key → service URI |
| `config` | The normalised configuration (after defaults) of every service and job, including disabled ones. |

## Examples

| Example | Shows |
|---|---|
| [basic](examples/basic) | one public service |
| [services](examples/services) | four services: public web, authenticated API with probes, secrets and a connector, gRPC, internal admin |
| [sidecars-and-volumes](examples/sidecars-and-volumes) | multi-container services and every volume type |
| [jobs](examples/jobs) | parallel batch jobs, run-on-deploy migrations, schedules with overrides |
| [traffic-management](examples/traffic-management) | canary and blue/green with named revisions and tags |
| [scheduled-workloads](examples/scheduled-workloads) | Cloud Scheduler calls to services and job executions |
| [gpu-inference](examples/gpu-inference) | GPU service and job |
| [multi-environment](examples/multi-environment) | one file for dev, staging and prod |
| [complete](examples/complete) | every configuration key (checked by a test) |
| [standalone-modules](examples/standalone-modules) | the submodules from plain HCL |

## Documentation

- [docs/configuration.md](docs/configuration.md): file structure, templating, defaults and how they merge, precedence, validation
- [docs/services.md](docs/services.md): every key of a service, its revision template, containers, volumes, traffic, schedules and IAM
- [docs/jobs.md](docs/jobs.md): every key of a job and its schedules
- [docs/design.md](docs/design.md), [docs/testing.md](docs/testing.md), [docs/troubleshooting.md](docs/troubleshooting.md)

## Testing

```bash
scripts/test.sh     # fmt, validate, 60+ terraform tests (mocked provider), schema/doc checks, real-provider plans of every example
```

A live test deploys [tests/integration](tests/integration) into a real project, checks that a second plan is empty, updates in place and destroys everything; see [docs/testing.md](docs/testing.md).

## License

Apache 2.0, see [LICENSE](LICENSE).
