# Complete example

Every configuration key the module supports, across seven services and four jobs (one of each disabled). `tests/python/test_schema.py` fails if a key is ever missing here.

| Entry | Highlights |
|---|---|
| `storefront` (deployed as `shop-storefront`) | two containers (nginx ingress + app) with every probe type, `depends_on`, base image updates, `empty_dir` and secret volumes with octal modes, Direct VPC egress, CMEK, service and revision scaling, named revision with a 90/10 traffic split, conditional IAM, a schedule with every option |
| `catalog` | gRPC (`h2c`) with gRPC startup, liveness and readiness probes, VPC connector |
| `admin` | internal load balancer, IAP, `default_uri_disabled`, manual scaling, Binary Authorization policy with break-glass, `PREVENT` deletion |
| `reports` | other project and region, Cloud SQL, Cloud Storage FUSE and NFS volumes, `sub_path` |
| `recommender` | GPU |
| `status` | public through `invoker_iam_disabled` |
| `etl` (deployed as `shop-etl`) | every job and template key, Cloud SQL proxy sidecar with an HTTP startup probe, two schedules (one with overrides of a named container) |
| `migrate` | `run_execution_token` |
| `embeddings` | GPU job in another project and region, image from `defaults.job_container` |
| `legacy-storefront`, `old-export` | `enabled: false` |
