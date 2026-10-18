# modules/schedule

One Cloud Scheduler job with an HTTP target, authenticated with an OAuth token (for Google APIs, such as executing a Cloud Run job or a Workflow) or an OIDC token (for services such as Cloud Run). `modules/service` and `modules/job` use it for their `schedules`; it works for any target.

```hcl
module "nightly_workflow" {
  source = "github.com/dsbip/terraform-google-cloud-run-yaml//modules/schedule?ref=v1.0.0"

  name       = "nightly-workflow"
  project_id = "my-project"
  region     = "europe-west1"
  schedule   = "30 1 * * *"
  time_zone  = "Europe/Berlin"

  uri         = "https://workflowexecutions.googleapis.com/v1/projects/my-project/locations/europe-west1/workflows/nightly/executions"
  body        = jsonencode({ argument = jsonencode({ source = "scheduler" }) })
  headers     = { "Content-Type" = "application/json" }
  oauth_token = { service_account_email = "scheduler@my-project.iam.gserviceaccount.com" }
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | Letters, digits, hyphens, underscores. |
| `project_id`, `region` | `string` | | Where the scheduler job lives. |
| `schedule` | `string` | | Cron expression. |
| `time_zone` | `string` | `null` (UTC) | tz database name. |
| `description` | `string` | `null` | |
| `paused` | `bool` | `null` | Create paused. |
| `attempt_deadline` | `string` | `null` | e.g. `320s`. |
| `retry_config` | `object` | `null` | `{ retry_count, max_retry_duration, min_backoff_duration, max_backoff_duration, max_doublings }`. |
| `uri` | `string` | | Target URI. |
| `http_method` | `string` | `"POST"` | |
| `headers` | `map(string)` | `{}` | |
| `body` | `string` | `null` | Plain text; base64-encoded by the module. |
| `oauth_token` | `object` | `null` | `{ service_account_email, scope = cloud-platform }`. |
| `oidc_token` | `object` | `null` | `{ service_account_email, audience }`. Exactly one of the two tokens. |

## Outputs

`id`, `name`, `state` and `job` (the whole `google_cloud_scheduler_job`).
