# Examples

Each example is a root module with a `config.yaml` (the standalone one has HCL only) and a `main.tf` that calls the module. All of them are planned with the real provider in CI (`tests/python/test_example_plans.py`) and checked against their README by `tests/examples.tftest.hcl`.

| Example | Services | Jobs | Shows |
|---|---|---|---|
| [basic](basic) | 1 | | one public service |
| [services](services) | 4 | | public web, authenticated API (warm instances, always-on CPU, probes, secrets, connector), gRPC, internal admin; service and container defaults |
| [sidecars-and-volumes](sidecars-and-volumes) | 2 | | nginx + app + OpenTelemetry sidecars, `depends_on`, in-memory, secret, Cloud SQL, Cloud Storage FUSE and NFS volumes |
| [jobs](jobs) | | 4 | parallel tasks, retries, Direct VPC, Cloud SQL, schedules with overrides, run-on-deploy migrations, one image for many jobs |
| [traffic-management](traffic-management) | 3 | | canary, blue/green, tags |
| [scheduled-workloads](scheduled-workloads) | 1 | 1 | five Cloud Scheduler jobs: GET/POST service calls with bodies, retries, audiences, regions, paused; job runs with overrides |
| [gpu-inference](gpu-inference) | 1 | 1 | NVIDIA L4 GPU service and job |
| [multi-environment](multi-environment) | 1–2 per env | 1 per env | dev, staging and prod from one file |
| [complete](complete) | 7 | 4 | every configuration key |
| [standalone-modules](standalone-modules) | 1 | 1 | `modules/service`, `modules/job` and `modules/schedule` without YAML |

Run one:

```bash
cd examples/basic
terraform init
terraform apply -var project_id=my-project
```
