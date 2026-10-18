# modules/job

Deploys one Cloud Run job with its invoker grants, IAM and Cloud Scheduler executions. The YAML root module calls it once per job; it works the same from plain HCL.

```hcl
module "etl" {
  source = "github.com/dsbip/terraform-google-cloud-run-yaml//modules/job?ref=v1.0.0"

  name                = "etl"
  project_id          = "my-project"
  region              = "europe-west1"
  deletion_protection = false

  template = {
    task_count  = 20
    parallelism = 5
    timeout     = "3600s"
    containers  = [{ image = "europe-docker.pkg.dev/my-project/batch/etl:2.0.0", args = ["--incremental"] }]
  }

  invokers = ["serviceAccount:scheduler@my-project.iam.gserviceaccount.com"]
  iam = [{
    role    = "roles/run.jobsExecutorWithOverrides"
    members = ["serviceAccount:scheduler@my-project.iam.gserviceaccount.com"]
  }]
  schedules = {
    nightly = { schedule = "0 2 * * *", service_account_email = "scheduler@my-project.iam.gserviceaccount.com" }
    monthly = {
      schedule              = "0 1 1 * *"
      service_account_email = "scheduler@my-project.iam.gserviceaccount.com"
      overrides             = { args = ["--full"], task_count = 100 }
    }
  }
}
```

## Resources

| Resource | When |
|---|---|
| `google_cloud_run_v2_job.this` | always |
| `google_cloud_run_v2_job_iam_member.invoker` | one per `invokers` member (`roles/run.invoker`: may execute the job) |
| `google_cloud_run_v2_job_iam_member.this` | one per `iam` role and member |
| `module.schedule` ([modules/schedule](../schedule/README.md)) | one per `schedules` entry: `<name>-<key>`, `POST .../jobs/NAME:run` with an OAuth token and the overrides as the request body |

## Inputs

`name`, `project_id`, `region` and `template` are required. The others mirror [docs/jobs.md](../../docs/jobs.md): `labels`, `annotations`, `client`, `client_version`, `launch_stage`, `deletion_protection`, `deletion_policy`, `binary_authorization`, `start_execution_token` or `run_execution_token`, `invokers`, `iam`, `schedules`. `template` combines the execution template (`labels`, `annotations`, `parallelism`, `task_count`) and the task template (`containers`, `volumes`, `max_retries`, `timeout`, `service_account`, `execution_environment`, `encryption_key`, `vpc_access`, `node_selector`, `gpu_zonal_redundancy_disabled`).

## Outputs

| Name | Description |
|---|---|
| `id`, `name`, `project_id`, `region` | Identity of the job. |
| `run_uri` | Admin API URI that executes the job. |
| `latest_created_execution` | Latest execution, if any. |
| `service_account` | Runtime service account. |
| `schedules` | Scheduler job names by key. |
| `invoker_members`, `iam_members` | The grants made. |
| `job`, `scheduler_jobs` | The whole resources. |
