# Standalone modules example

The YAML layer is optional. [`modules/service`](../../modules/service), [`modules/job`](../../modules/job) and [`modules/schedule`](../../modules/schedule) are ordinary modules with typed inputs:

- `module.hello`: a public service.
- `module.report`: a job with a secret and a daily schedule.
- `module.workflow_trigger`: a Cloud Scheduler job for a target outside this module (a Workflows execution).

The YAML root module calls `modules/service` and `modules/job` in exactly this way, once per entry.
