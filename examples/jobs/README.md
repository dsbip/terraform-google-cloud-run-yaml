# Jobs example

| Job | Shows |
|---|---|
| `nightly-etl` | 100 tasks with parallelism 10, retries, a two hour timeout, Direct VPC egress with all traffic, Cloud SQL, a secret; two schedules, one with argument, task count and timeout overrides |
| `db-migrate` | `run_execution_token`: a new release runs the migration once, and `terraform apply` waits until it has finished |
| `thumbnail-backfill` | the image comes from `defaults.job_container`; only the arguments differ |
| `cleanup` | executed by another system: only its service account is an invoker |

`defaults.job_container` sets the image, resources and an environment variable for every container; `defaults.jobs` sets the runtime service account, retries and timeout for every job.

Each schedule becomes a Cloud Scheduler job (`<job>-<schedule>`) that calls the Cloud Run Admin API with an OAuth token. Its service account must be allowed to run the job: `roles/run.invoker` (through `invokers`), plus `roles/run.jobsExecutorWithOverrides` when the schedule has `overrides`.
