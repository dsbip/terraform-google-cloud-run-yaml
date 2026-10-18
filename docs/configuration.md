# Configuration file

The configuration is one YAML mapping with four top-level keys, all optional:

```yaml
project_id: my-project        # default project of every service and job

defaults:                     # applied underneath every entry
  region: europe-west1
  labels: { team: payments }
  services: { ... }           # any service key except name
  jobs: { ... }               # any job key except name
  service_container: { ... }  # any service container key except name
  job_container: { ... }      # any job container key except name

services:                     # one entry per service, keyed by a logical key
  api: { ... }

jobs:                         # one entry per job
  nightly: { ... }
```

| Key | Description |
|---|---|
| `project_id` | Default project for every service and job in the file. Overrides the module's `project_id` variable; an entry's own `project_id` overrides it. |
| `defaults` | Values every entry inherits, see [Defaults](#defaults). |
| `services` | Cloud Run services keyed by logical key, see [services.md](services.md). |
| `jobs` | Cloud Run jobs keyed by logical key, see [jobs.md](jobs.md). |

The key is the default name, the key of every output and part of every Terraform address (`module.service["api"]`), so renaming a key replaces the service. An entry may be empty (`api:`), in which case it consists of defaults only.

## Templating

`config_file` is rendered with Terraform's [`templatefile()`](https://developer.hashicorp.com/terraform/language/functions/templatefile) before it is parsed:

- `${name}` is replaced with a value from `template_vars`. `project_id` and `region` (the module variables) are always available.
- Expressions work: `${env == "prod" ? 20 : 2}`, `${upper(team)}`.
- `%{ if cond ~}` ... `%{ else ~}` ... `%{ endif ~}` and `%{ for x in list ~}` add or remove whole blocks; the `~` strips the line break.
- `$${` produces a literal `${`.

`config_yaml` is used as-is; to template inline YAML, call `templatefile()` yourself or use `yamlencode()` on an HCL object. Values must be known at plan time.

To keep a templated file valid YAML *before* rendering (so editors and the JSON Schema can check it), quote placeholders that contain `: `, quotes or braces, and quote `${...}` inside flow collections:

```yaml
task_count: '${env == "prod" ? 20 : 2}'
invokers: ["serviceAccount:scheduler@${project_id}.iam.gserviceaccount.com"]
```

## Defaults

| Key | Description |
|---|---|
| `region` | Default region. Overrides the module's `region` variable; an entry's `region` (or `defaults.services.region` / `defaults.jobs.region`) overrides it. |
| `labels` | Labels added to every service and job, over the module's `labels` variable. |
| `services` | Any service key except `name`, merged underneath every service. |
| `jobs` | Any job key except `name`, merged underneath every job. |
| `service_container` | Any service container key except `name`, merged underneath **every container of every service** (ingress containers and sidecars). |
| `job_container` | Any job container key except `name`, merged underneath every container of every job. An `image` here lets many jobs share one image and differ only in `args`. |

### How defaults merge

Entry defaults (`defaults.services`, `defaults.jobs`) are merged first, then container defaults into each resulting container. Both merges go **three levels deep**:

| Level | Entry example | Container example | Rule |
|---|---|---|---|
| 1 | `ingress`, `template`, `invokers` | `image`, `env`, `resources` | the entry's value wins; mappings merge one level down |
| 2 | `template.service_account`, `template.scaling` | `env.LOG_LEVEL`, `resources.limits`, `resources.cpu_idle` | the entry's value wins; mappings merge one level down |
| 3 | `template.scaling.max_instance_count`, `template.vpc_access.connector` | `resources.limits.memory` | the entry's value wins; nothing deeper merges |

With

```yaml
defaults:
  services:
    template:
      service_account: run@my-project.iam.gserviceaccount.com
      scaling: { max_instance_count: 20 }
  service_container:
    resources:
      limits: { cpu: "1", memory: 512Mi }
    env: { LOG_LEVEL: info }

services:
  api:
    template:
      scaling: { min_instance_count: 2 }
      containers:
        - image: api
          resources:
            limits: { memory: 2Gi }
          env: { MODE: fast }
```

`api` runs as `run@...` with `min_instance_count: 2`, `max_instance_count: 20`, `limits: { cpu: "1", memory: 2Gi }` and `env: { LOG_LEVEL: info, MODE: fast }`.

- **Lists are replaced**, never concatenated: `containers`, `volumes`, `traffic`, `invokers`, `iam`, `args`, `volume_mounts`, ...
- **Empty keys never override**: `description:` with no value is the same as leaving the key out.
- `schedules` is a mapping, so default schedules are added to every entry; set schedules on the entries instead.
- Labels merge in this order, later wins: module `labels` → `defaults.labels` → `defaults.services.labels` / `defaults.jobs.labels` → entry `labels`.

## Precedence

| Setting | Highest → lowest |
|---|---|
| project | entry `project_id` → `defaults.services`/`defaults.jobs` `project_id` → top-level `project_id` → module `project_id` |
| region | entry `region` → `defaults.services`/`defaults.jobs` `region` → `defaults.region` → module `region` |
| name | entry `name` → YAML key |

An entry whose project or region cannot be determined is a validation error.

## Enabling and disabling

`enabled: false` keeps a service or job in the file without deploying it. It is still validated. With templating: `enabled: ${env == "dev"}`.

## Validation

Before anything is planned, the module checks the whole file and reports every problem at once, each prefixed with its YAML path. While there are problems, nothing is planned.

Driven by the [JSON Schema](../schemas/cloud-run-config.schema.json):

- unknown keys, with suggestions for likely typos (so a `liveness_probe` on a job container is reported: jobs don't have one);
- types, enumerations (`ingress`, `execution_environment`, `traffic[*].type`, ...), ranges (`max_instance_request_concurrency` 1–1000, ports, retries, ...), minimum and maximum list lengths;
- patterns: service names (≤ 49 characters), job names (≤ 63), durations (`300s`), schedule paths, IAM members, octal modes;
- required keys of nested objects (`volumes[*].name`, `volume_mounts[*].mount_path`, `secret_env.*.secret`, `schedules.*.schedule`, `iam[*].role`, ...).

Rules beyond the schema, checked after defaults are merged:

- a project and a region must be determinable; the key must be a valid name unless `name` is set; keys that YAML read as booleans are reported;
- a `template` with `containers`, and an `image` on every container;
- several containers: every one has a unique name, and for services exactly one (the ingress container) sets `ports`;
- `depends_on`, `volume_mounts[*].name` and job schedule `overrides.container` must name existing containers and volumes;
- volume names are unique and each volume sets exactly one kind; Cloud Storage and NFS volumes don't run on the first generation execution environment;
- a variable is not in both `env` and `secret_env`; a probe has at most one of `http_get`, `tcp_socket` and `grpc`;
- unquoted octal-looking modes (`default_mode: 444`) are reported, because YAML reads them as decimal numbers;
- `node_selector` needs a `nvidia.com/gpu` limit; `vpc_access` has `connector` or `network_interfaces`, not both, and `egress` needs one of them; `min_instance_count` ≤ `max_instance_count`; `MANUAL` scaling needs `manual_instance_count`; Binary Authorization has `use_default` or `policy`;
- traffic percentages add up to 100, `REVISION` targets name a revision and `LATEST` targets don't;
- schedules have a `service_account_email`; jobs set at most one execution token;
- no two enabled services (or jobs) share project, region and name; `name` cannot be a default.

The submodules validate their own inputs too, so they fail early when used without YAML.

## YAML gotchas

- Terraform's `yamldecode()` reads unquoted `yes`, `no`, `on`, `off`, `true` and `false` as booleans, also as keys. The module reports keys that became `true` or `false`; quote them (`"on":`).
- An unquoted `0444` is the decimal number 444, not octal. Write file modes as quoted octal strings (`default_mode: "0444"`) or as decimal numbers (`292`). `0o444` also works.
- Values that look like numbers become numbers (`version: 1.10` is `1.1`); quote them when the exact text matters.
- Environment variable values may be numbers or booleans; they are converted to strings.
