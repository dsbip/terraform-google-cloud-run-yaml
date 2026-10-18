# Jobs

Each entry under `jobs` deploys one Cloud Run job (`google_cloud_run_v2_job`), plus its invoker grants, IAM and schedules. A job runs one or more tasks to completion; each execution starts `task_count` tasks, `parallelism` at a time, and every task gets `CLOUD_RUN_TASK_INDEX` and `CLOUD_RUN_TASK_COUNT`.

```yaml
jobs:
  nightly-etl:
    template:
      task_count: 100
      parallelism: 10
      max_retries: 3
      timeout: 3600s
      containers:
        - image: europe-docker.pkg.dev/my-project/batch/etl:2.0.0
          args: [--incremental]
    invokers: ["serviceAccount:scheduler@my-project.iam.gserviceaccount.com"]
    schedules:
      nightly:
        schedule: "0 2 * * *"
        service_account_email: scheduler@my-project.iam.gserviceaccount.com
```

## Job

| Key | Description |
|---|---|
| `enabled` | `false` skips the job (default `true`); it is still validated. |
| `name` | Job name, default: the YAML key. Lowercase letters, digits and hyphens, starting with a letter, at most 63 characters. |
| `project_id` | Project of this job. |
| `region` | Region, e.g. `europe-west1`. |
| `labels` | Labels, merged over the module, `defaults.labels` and `defaults.jobs.labels` labels. |
| `annotations` | Job annotations. |
| `client`, `client_version` | Name and version of the deploying tool. |
| `launch_stage` | `GA`, `BETA` or `ALPHA`. |
| `deletion_protection` | Whether `terraform destroy` may delete the job. **The provider default is `true`.** |
| `deletion_policy` | `DELETE`, `PREVENT` or `ABANDON`. |
| `binary_authorization` | `{ use_default, policy, breakglass_justification }`, as for [services](services.md#binary_authorization). |
| `start_execution_token` | Changing this value starts an execution when the job is created or updated; `apply` waits until it has started. |
| `run_execution_token` | Changing this value runs an execution when the job is created or updated; `apply` waits until it has **completed** (e.g. database migrations on deploy). Use one of the two tokens. |
| `template` | What an execution runs, see [template](#template). Required (here or in defaults). |
| `invokers` | Members granted `roles/run.invoker`: allowed to execute the job. Scheduler service accounts belong here. |
| `iam` | Other IAM grants, as for [services](services.md#invokers-and-iam), e.g. `roles/run.jobsExecutorWithOverrides`. |
| `schedules` | See [Schedules](#schedules). |

## template

The provider splits a job template into an execution template and a task template; the YAML has both in one mapping.

| Key | Description |
|---|---|
| `labels`, `annotations` | Execution labels and annotations. |
| `parallelism` | Tasks running at the same time (default: as many as possible). |
| `task_count` | Tasks per execution (default 1). |
| `max_retries` | Retries per failed task (0–10, default 3). |
| `timeout` | Time limit per task attempt, e.g. `3600s` (see the Cloud Run quotas page for the maximum). |
| `service_account` | Runtime service account email. |
| `execution_environment` | `EXECUTION_ENVIRONMENT_GEN1` or `EXECUTION_ENVIRONMENT_GEN2`. |
| `encryption_key` | Cloud KMS key for the image (CMEK). |
| `gpu_zonal_redundancy_disabled` | Use GPU capacity without zonal redundancy. |
| `vpc_access` | `{ connector, egress, network_interfaces }`, as for [services](services.md#vpc_access). |
| `node_selector` | GPUs: `{ accelerator: nvidia-l4 }`. |
| `containers` | 1–10 containers, see [Containers](#containers). |
| `volumes` | Volumes, exactly as for [services](services.md#volumes) (secret items always get a version, default `latest`). |

## Containers

Job containers take the same keys as [service containers](services.md#containers) except those that only make sense for request serving: no `ports`, `liveness_probe`, `readiness_probe` or `base_image_uri`, and `resources` has only `limits`.

| Key | Description |
|---|---|
| `name` | Container name. Required with several containers and for schedule `overrides.container`. |
| `image` | Image. Required (here or in `defaults.job_container`, which lets many jobs share one image). |
| `command`, `args`, `working_dir` | Entrypoint, arguments and working directory. |
| `depends_on` | Containers that must start first (e.g. a Cloud SQL proxy sidecar). |
| `env`, `secret_env` | Environment variables and Secret Manager variables (`NAME: { secret, version }`). |
| `resources` | `{ limits: { cpu, memory, nvidia.com/gpu } }`, see below. |
| `volume_mounts` | `{ name, mount_path, sub_path }`. |
| `startup_probe` | As for [services](services.md#probes); useful for sidecars that other containers depend on. |

`resources`:

| Key | Description |
|---|---|
| `limits` | `{ cpu: "4", memory: 8Gi }`, plus `nvidia.com/gpu: "1"` for GPUs. |

## Schedules

Each entry under `schedules` creates a Cloud Scheduler job named `<job>-<key>` that executes the job through the Cloud Run Admin API (`POST https://run.googleapis.com/v2/projects/P/locations/R/jobs/NAME:run`) with an OAuth token.

```yaml
schedules:
  nightly:
    schedule: "0 2 * * *"
    time_zone: Europe/Berlin
    service_account_email: scheduler@my-project.iam.gserviceaccount.com
  monthly-full:
    schedule: "0 1 1 * *"
    service_account_email: scheduler@my-project.iam.gserviceaccount.com
    overrides:
      container: etl
      args: [--full]
      env: { BATCH_SIZE: 20000 }
      task_count: 400
      timeout: 14400s
```

| Key | Description |
|---|---|
| `schedule` | Cron expression. Required. |
| `time_zone` | tz database name (default UTC). |
| `description` | Description of the scheduler job. |
| `paused` | Create the scheduler job paused. |
| `region` | Cloud Scheduler region (default: the job's region). |
| `service_account_email` | Identity of the call. Required. It needs `roles/run.invoker` on the job (add it to `invokers`) and, with `overrides`, `roles/run.jobsExecutorWithOverrides` (add it to `iam`). |
| `attempt_deadline` | Deadline per attempt, e.g. `320s`. |
| `retry_config` | Retries of failed attempts, as for [service schedules](services.md#schedules). |
| `overrides` | Changes for executions started by this schedule, see below. |

`overrides`:

| Key | Description |
|---|---|
| `container` | Container whose `args` and `env` are overridden (default: the first container). |
| `args` | Arguments for this run (replace the container's `args`). |
| `env` | Environment variables for this run. |
| `task_count` | Tasks for this run. |
| `timeout` | Task timeout for this run, e.g. `600s`. |
