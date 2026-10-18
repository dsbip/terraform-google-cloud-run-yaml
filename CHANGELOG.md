# Changelog

All notable changes to this module are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-10-18

First release.

### Added

- YAML-driven deployment of Cloud Run services and jobs, any number per file.
- Every service, revision template, container, probe and volume setting of `google_cloud_run_v2_service`, and every job, execution and task template setting of `google_cloud_run_v2_job`, including sidecars, GPUs, Direct VPC egress, CMEK, Binary Authorization, IAP and execution tokens.
- `env` and `secret_env` mappings for environment variables; quoted octal strings for secret file modes.
- Traffic splits with `LATEST`/`REVISION` short forms and tags.
- Schedules: Cloud Scheduler calls to services (OIDC) and job executions through the Admin API (OAuth) with argument, environment, task count and timeout overrides.
- Invokers (`roles/run.invoker`) and IAM with conditions on services and jobs.
- `defaults` for region, labels, services, jobs and every service or job container, merged three levels deep.
- Templating of `config_file` with `templatefile()`, and `enabled` per entry.
- Validation driven by the JSON Schema plus cross-field rules (container and volume references, exclusive options, traffic sums, octal-looking modes, duplicates), all reported at once with YAML paths.
- Standalone submodules `modules/service`, `modules/job` and `modules/schedule`.
- Ten examples, 60+ unit tests with a mocked provider, real-provider plan tests, schema and documentation tests, and a live test.
