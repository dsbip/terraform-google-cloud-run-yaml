# Services

Each entry under `services` deploys one Cloud Run service (`google_cloud_run_v2_service`), plus its invoker grants, IAM and schedules. Key names follow the Google provider, so the [provider documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service) applies too. Differences: single-element blocks are mappings (`ports: { ... }` rather than a list), environment variables are the mappings `env` and `secret_env`, `traffic[*].type` accepts `LATEST`/`REVISION`, and `region` replaces `location`.

Containers, volumes, probes and VPC access described on this page work the same way for [jobs](jobs.md).

```yaml
services:
  api:
    description: Order API.
    ingress: INGRESS_TRAFFIC_ALL
    template:
      service_account: api@my-project.iam.gserviceaccount.com
      scaling: { min_instance_count: 1, max_instance_count: 50 }
      containers:
        - image: europe-docker.pkg.dev/my-project/app/api:1.4.2
          env: { LOG_LEVEL: info }
          secret_env:
            DB_PASSWORD: { secret: api-db-password }
    invokers: [allUsers]
```

## Service

| Key | Description |
|---|---|
| `enabled` | `false` skips the service (default `true`); it is still validated. |
| `name` | Service name, default: the YAML key. Lowercase letters, digits and hyphens, starting with a letter, at most 49 characters. |
| `project_id` | Project of this service. |
| `region` | Region, e.g. `europe-west1`. |
| `description` | Description. |
| `labels` | Labels, merged over the module, `defaults.labels` and `defaults.services.labels` labels. |
| `annotations` | Service annotations (revision annotations go in `template.annotations`). |
| `client`, `client_version` | Name and version of the deploying tool, shown in the console. |
| `ingress` | `INGRESS_TRAFFIC_ALL` (default), `INGRESS_TRAFFIC_INTERNAL_ONLY` or `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`. |
| `launch_stage` | `GA`, `BETA` or `ALPHA`; preview features need `BETA` or `ALPHA`. |
| `deletion_protection` | Whether `terraform destroy` may delete the service. **The provider default is `true`**; set `false` for services that may be destroyed. |
| `deletion_policy` | `DELETE`, `PREVENT` or `ABANDON` (removed from state, left running). |
| `custom_audiences` | Extra audiences accepted in ID tokens, e.g. a custom domain. |
| `default_uri_disabled` | Disable the `run.app` URL (only reachable through a load balancer). |
| `invoker_iam_disabled` | Skip the IAM invoker check: anyone who can reach the service can call it. Makes a service public without `allUsers` (which the *Domain restricted sharing* policy may block). |
| `iap_enabled` | Put Identity-Aware Proxy in front of the service. |
| `binary_authorization` | See [binary_authorization](#binary_authorization). |
| `scaling` | Service-level scaling, see [scaling](#scaling). |
| `template` | The revision template, see [template](#template). Required (here or in defaults). |
| `traffic` | Traffic split, see [traffic](#traffic). |
| `invokers`, `iam` | See [Invokers and IAM](#invokers-and-iam). |
| `schedules` | Scheduled calls, see [Schedules](#schedules). |

### binary_authorization

| Key | Description |
|---|---|
| `use_default` | Enforce the project's default policy. |
| `policy` | Policy name: `projects/P/platforms/cloudRun/policies/NAME`. Use this or `use_default`. |
| `breakglass_justification` | Reason to bypass the policy in an emergency (break-glass, audited). |

### scaling

Service-level settings apply to all revisions together (unlike `template.scaling`, which applies per revision).

| Key | Description |
|---|---|
| `min_instance_count` | Minimum instances across the service. |
| `max_instance_count` | Maximum instances across the service. |
| `scaling_mode` | `AUTOMATIC` (default) or `MANUAL`. |
| `manual_instance_count` | Number of instances with `scaling_mode: MANUAL`. |

## template

| Key | Description |
|---|---|
| `revision` | Revision name; must start with the service name and a hyphen (e.g. `api-v42`). Needed for `traffic` targets of type `REVISION`. Default: generated. |
| `labels`, `annotations` | Revision labels and annotations. |
| `timeout` | Request timeout, e.g. `300s` (up to `3600s`). |
| `service_account` | Runtime service account email. Default: the Compute Engine default service account; set a dedicated one. |
| `execution_environment` | `EXECUTION_ENVIRONMENT_GEN1` or `EXECUTION_ENVIRONMENT_GEN2`. Cloud Storage and NFS volumes need gen2. |
| `encryption_key` | Cloud KMS key for the image (CMEK). |
| `max_instance_request_concurrency` | Concurrent requests per instance (1–1000; default 80). |
| `session_affinity` | Send a client's requests to the same instance. |
| `gpu_zonal_redundancy_disabled` | Use GPU capacity without zonal redundancy (cheaper). |
| `health_check_disabled` | Disable the default TCP startup check. |
| `scaling` | Per-revision autoscaling: `min_instance_count` (kept warm), `max_instance_count`. |
| `vpc_access` | VPC egress, see [vpc_access](#vpc_access). |
| `node_selector` | GPUs: `{ accelerator: nvidia-l4 }`. Needs a `nvidia.com/gpu` limit on a container. |
| `containers` | 1–10 containers, see [Containers](#containers). |
| `volumes` | Volumes the containers can mount, see [Volumes](#volumes). |

### vpc_access

| Key | Description |
|---|---|
| `connector` | Serverless VPC Access connector: `projects/P/locations/R/connectors/C`. |
| `network_interfaces` | Direct VPC egress instead of a connector: a list of `{ network, subnetwork, tags }`. |
| `egress` | `PRIVATE_RANGES_ONLY` or `ALL_TRAFFIC` through the VPC. Needs `connector` or `network_interfaces`. |

`network_interfaces` items:

| Key | Description |
|---|---|
| `network` | VPC network name or self link (optional with `subnetwork`). |
| `subnetwork` | Subnetwork name or self link. |
| `tags` | Network tags, e.g. for firewall rules. |

`node_selector`:

| Key | Description |
|---|---|
| `accelerator` | GPU type, e.g. `nvidia-l4`. |

## Containers

```yaml
containers:
  - name: proxy                      # names are required with several containers
    image: nginx:1.27-alpine
    ports: { container_port: 8080 }  # exactly one container sets ports
    depends_on: [app]
  - name: app
    image: europe-docker.pkg.dev/my-project/app/api:1.4.2
    env: { PORT: 9000 }
    secret_env:
      API_KEY: { secret: api-key, version: "3" }
    resources:
      limits: { cpu: "2", memory: 1Gi }
    startup_probe:
      tcp_socket: { port: 9000 }
```

| Key | Description |
|---|---|
| `name` | Container name. Required when the template has several containers. Cannot be a default. |
| `image` | Image, e.g. `europe-docker.pkg.dev/P/repo/app:1.2.3`. Required (here or in `defaults.service_container`). |
| `command` | Entrypoint (replaces the image's `ENTRYPOINT`). |
| `args` | Arguments (replace the image's `CMD`). |
| `working_dir` | Working directory. |
| `depends_on` | Containers that must start (and pass their startup probe) first. |
| `base_image_uri` | Base image for automatic base image updates. |
| `env` | Plain environment variables. Numbers and booleans become strings. Merged with the container defaults key by key. |
| `secret_env` | Variables from Secret Manager: `NAME: { secret, version }`. |
| `resources` | See [resources](#resources). |
| `ports` | The port the ingress container listens on, see [ports](#ports). |
| `volume_mounts` | Volumes mounted into the container: `{ name, mount_path, sub_path }`. |
| `startup_probe`, `liveness_probe` | See [Probes](#probes). |
| `readiness_probe` | See [Probes](#probes). |

`secret_env` values:

| Key | Description |
|---|---|
| `secret` | Secret ID in the service's project, or `projects/P/secrets/S` for another project. Required. |
| `version` | Version, default `latest`. |

`volume_mounts` items:

| Key | Description |
|---|---|
| `name` | Name of a volume of the template. Required. |
| `mount_path` | Where to mount, e.g. `/secrets`. Cloud SQL volumes conventionally mount at `/cloudsql`. Required. |
| `sub_path` | Path inside the volume to mount instead of its root. |

### resources

| Key | Description |
|---|---|
| `limits` | `{ cpu: "2", memory: 1Gi }`, plus `nvidia.com/gpu: "1"` for GPUs. Merged with the container defaults key by key. |
| `cpu_idle` | `true` (default): CPU only during requests (request-based billing). `false`: always-on CPU (instance-based billing), needed for background work and GPUs. |
| `startup_cpu_boost` | Extra CPU while instances start. |

### ports

| Key | Description |
|---|---|
| `container_port` | Port number (default 8080, passed to the container as `PORT`). |
| `name` | `http1` (default) or `h2c` for end-to-end HTTP/2 and gRPC. |

### Probes

`startup_probe` and `liveness_probe` take one of `http_get`, `tcp_socket` and `grpc`:

| Key | Description |
|---|---|
| `initial_delay_seconds` | Seconds before the first probe (0–240). |
| `timeout_seconds` | Seconds before a probe times out. |
| `period_seconds` | Seconds between probes. |
| `failure_threshold` | Failures before the container is restarted (liveness) or the start fails (startup). |
| `http_get` | `{ path, port, http_headers: [{ name, value }] }`. |
| `tcp_socket` | `{ port }`. |
| `grpc` | `{ port, service }`: the gRPC health checking protocol. |

`readiness_probe` takes `http_get` (`{ path, port }`) or `grpc`:

| Key | Description |
|---|---|
| `failure_threshold` | Failures before the instance stops receiving requests. |
| `success_threshold` | Successes before it receives requests again. |
| `period_seconds` | Seconds between probes. |
| `timeout_seconds` | Seconds before a probe times out. |
| `http_get` | `{ path, port }`. |
| `grpc` | `{ port, service }`. |

Probe handlers:

| Handler | Key | Description |
|---|---|---|
| `http_get` | `path` | Path, e.g. `/healthz`. |
| | `port` | Port (default: the container port). |
| | `http_headers` | Request headers, each with a `name` (required) and a `value`. |
| `tcp_socket` | `port` | Port (default: the container port). |
| `grpc` | `port` | Port (default: the container port). |
| | `service` | Service name sent in the health check request. |

## Volumes

Each volume has a `name` and exactly one kind:

```yaml
volumes:
  - name: config
    secret:
      secret: app-config
      default_mode: "0444"                     # quoted octal (or decimal 292)
      items: [{ path: config.yaml, version: "3", mode: "0400" }]
  - name: cloudsql
    cloud_sql_instance: { instances: ["my-project:europe-west1:db"] }
  - name: scratch
    empty_dir: { medium: MEMORY, size_limit: 256Mi }
  - name: assets
    gcs: { bucket: my-assets, read_only: true, mount_options: [implicit-dirs] }
  - name: share
    nfs: { server: 10.0.0.2, path: /share, read_only: true }
```

| Kind | Key | Description |
|---|---|---|
| `secret` | `secret` | Secret ID or `projects/P/secrets/S`. Required. |
| | `default_mode` | Mode of all files: a quoted octal string (`"0444"`) or a decimal number (`292`). |
| | `items` | Versions to mount: `{ path, version, mode }` (`path` required, `version` default latest). Default: the latest version in a file named after the secret. |
| `cloud_sql_instance` | `instances` | Instance connection names (`project:region:instance`). Mount the volume at `/cloudsql`. |
| `empty_dir` | `medium` | `MEMORY`: in-memory scratch space. |
| | `size_limit` | e.g. `512Mi`. |
| `gcs` | `bucket` | Bucket mounted with Cloud Storage FUSE. Required. |
| | `read_only` | Mount read-only. |
| | `mount_options` | gcsfuse options, e.g. `[implicit-dirs]`. |
| `nfs` | `server` | Server IP or hostname (e.g. Filestore). Required. |
| | `path` | Exported path. |
| | `read_only` | Mount read-only. |

`secret` items:

| Key | Description |
|---|---|
| `path` | File name relative to the mount path. Required. |
| `version` | Version, default latest. |
| `mode` | File mode, quoted octal or decimal. |

YAML reads an unquoted `0444` as the decimal number 444; the module reports such values.

## traffic

```yaml
template:
  revision: api-v42
traffic:
  - { type: REVISION, revision: api-v41, percent: 90, tag: stable }
  - { type: REVISION, revision: api-v42, percent: 10, tag: canary }
```

| Key | Description |
|---|---|
| `type` | `LATEST` (the newest ready revision) or `REVISION`; the provider's long forms are accepted too. |
| `revision` | Revision name, with `type: REVISION` only. |
| `percent` | Share of traffic. All targets add up to 100. |
| `tag` | Gives the target its own URL, `https://TAG---SERVICE-HASH.run.app`. |

Without `traffic`, 100% goes to the latest revision.

## Invokers and IAM

```yaml
invokers: [allUsers]
iam:
  - role: roles/run.developer
    members: [group:api-devs@example.com]
  - role: roles/run.viewer
    members: [user:auditor@example.com]
    condition:
      title: audit-2026
      description: Audit access.
      expression: request.time < timestamp("2027-01-01T00:00:00Z")
```

- `invokers` grants `roles/run.invoker` (allowed to call the service; for jobs: to execute it). `allUsers` makes a service public.
- `iam` grants other roles on the service. A `roles/run.invoker` grant without condition for a member already in `invokers` is skipped.

Both are non-authoritative (`*_iam_member`): grants made outside Terraform are left alone.

`iam` items:

| Key | Description |
|---|---|
| `role` | Role, e.g. `roles/run.developer`. Required. |
| `members` | `user:`, `group:`, `serviceAccount:`, `domain:`, `principal://`, `principalSet://`, `allUsers`, `allAuthenticatedUsers`. At least one. |
| `condition` | IAM condition, see below. |

`condition`:

| Key | Description |
|---|---|
| `title` | Title. Required. |
| `expression` | CEL expression. Required. |
| `description` | Description. |

## Schedules

Each entry under `schedules` creates a Cloud Scheduler job named `<service>-<key>` that calls the service with an OIDC token.

```yaml
schedules:
  digest:
    schedule: "0 7 * * 1-5"
    time_zone: America/New_York
    path: /tasks/digest
    body: '{"dry_run": false}'
    headers: { Content-Type: application/json }
    service_account_email: scheduler@my-project.iam.gserviceaccount.com
invokers: ["serviceAccount:scheduler@my-project.iam.gserviceaccount.com"]
```

| Key | Description |
|---|---|
| `schedule` | Cron expression. Required. |
| `time_zone` | tz database name, e.g. `Europe/Berlin` (default UTC). |
| `description` | Description of the scheduler job. |
| `paused` | Create the scheduler job paused. |
| `region` | Cloud Scheduler region (default: the service's region; Cloud Scheduler is not available in every region). |
| `service_account_email` | Identity of the call. Required; it needs `roles/run.invoker`, so add it to `invokers`. |
| `path` | Path to call (default `/`). |
| `http_method` | `POST` (default), `GET`, `HEAD`, `PUT`, `DELETE`, `PATCH` or `OPTIONS`. |
| `headers` | Request headers. |
| `body` | Request body as plain text (the module base64-encodes it). |
| `audience` | OIDC audience (default: the service URL). |
| `attempt_deadline` | Deadline per attempt, e.g. `320s`. |
| `retry_config` | Retries of failed attempts, see below. |

`retry_config`:

| Key | Description |
|---|---|
| `retry_count` | Retries (0–5). |
| `max_retry_duration` | Time limit for retries, e.g. `600s`. |
| `min_backoff_duration` | Minimum wait between retries, e.g. `5s`. |
| `max_backoff_duration` | Maximum wait between retries, e.g. `3600s`. |
| `max_doublings` | How often the wait doubles before it grows linearly. |
