# modules/service

Deploys one Cloud Run service with its invoker grants, IAM and Cloud Scheduler calls. The YAML root module calls it once per service; it works the same from plain HCL.

```hcl
module "api" {
  source = "github.com/dsbip/terraform-google-cloud-run-yaml//modules/service?ref=v1.0.0"

  name                = "api"
  project_id          = "my-project"
  region              = "europe-west1"
  deletion_protection = false

  template = {
    service_account = "api@my-project.iam.gserviceaccount.com"
    scaling         = { min_instance_count = 1, max_instance_count = 20 }
    containers = [{
      image      = "europe-docker.pkg.dev/my-project/app/api:1.4.2"
      env        = { LOG_LEVEL = "info" }
      secret_env = { DB_PASSWORD = { secret = "api-db-password" } }
      resources  = { limits = { cpu = "1", memory = "512Mi" } }
    }]
  }

  invokers = ["allUsers"]
  schedules = {
    warmup = {
      schedule              = "*/10 * * * *"
      path                  = "/warm"
      service_account_email = "scheduler@my-project.iam.gserviceaccount.com"
    }
  }
}
```

## Resources

| Resource | When |
|---|---|
| `google_cloud_run_v2_service.this` | always |
| `google_cloud_run_v2_service_iam_member.invoker` | one per `invokers` member (`roles/run.invoker`) |
| `google_cloud_run_v2_service_iam_member.this` | one per `iam` role and member (redundant unconditional invoker grants skipped) |
| `module.schedule` ([modules/schedule](../schedule/README.md)) | one per `schedules` entry: `<name>-<key>`, OIDC token, audience = service URL |

## Inputs

`name`, `project_id`, `region` are required; `template` (with at least one container) too. Everything else is optional and mirrors the keys documented in [docs/services.md](../../docs/services.md): `description`, `labels`, `annotations`, `client`, `client_version`, `ingress`, `launch_stage`, `deletion_protection` (null: provider default `true`), `deletion_policy`, `custom_audiences`, `default_uri_disabled`, `invoker_iam_disabled`, `iap_enabled`, `binary_authorization`, `scaling`, `traffic`, `invokers`, `iam`, `schedules`.

Differences from the YAML: secret file modes are numbers (the YAML layer converts `"0444"`); there are no defaults to merge.

## Outputs

| Name | Description |
|---|---|
| `id`, `name`, `project_id`, `region` | Identity of the service. |
| `uri`, `urls` | Service URLs. |
| `latest_ready_revision` | Revision currently serving. |
| `service_account` | Runtime service account. |
| `schedules` | Scheduler job names by key. |
| `invoker_members`, `iam_members` | The grants made. |
| `service`, `scheduler_jobs` | The whole resources. |
