# Scheduled workloads example

Five Cloud Scheduler jobs, named `<service or job>-<schedule key>`:

| Schedule | Target | Shows |
|---|---|---|
| `maintenance-api-cache-warmup` | service, `GET /tasks/warm-cache` | every 10 minutes, attempt deadline |
| `maintenance-api-daily-digest` | service, `POST /tasks/digest` | weekdays in a time zone, JSON body and header, retries with backoff |
| `maintenance-api-quarterly-report` | service | custom OIDC audience, scheduler in another region, created paused |
| `backup-hourly` | job | plain execution |
| `backup-weekly-verify` | job | argument, environment and timeout overrides |

Service schedules authenticate with an OIDC token whose audience is the service URL (or `audience`); job schedules call the Cloud Run Admin API with an OAuth token. The scheduler service account is listed in `invokers`; schedules with `overrides` also need `roles/run.jobsExecutorWithOverrides`.

The service keeps the default ingress and is protected by IAM: only the scheduler's service account may call it. Check the [Cloud Run ingress documentation](https://cloud.google.com/run/docs/securing/ingress) before restricting ingress on a scheduled service.
