# Services example

Four services with different runtime profiles that share one set of defaults:

| Service | Shows |
|---|---|
| `storefront` | public, port 3000, concurrency 250, startup CPU boost, environment variable merged with the defaults |
| `orders-api` | warm instances, always-on CPU (`cpu_idle: false`), request timeout, VPC connector, secret environment variables (pinned and cross-project), startup/liveness/readiness probes with headers, developer IAM |
| `catalog-grpc` | HTTP/2 (`h2c`) with gRPC startup and liveness probes |
| `admin` | internal load balancer only, `default_uri_disabled`, custom audience, session affinity |

`defaults.services` gives every service the runtime service account, the second generation execution environment and `max_instance_count: 20`; `defaults.service_container` gives every container 1 CPU / 512Mi and two environment variables. `orders-api` overrides `max_instance_count` and adds `min_instance_count` (level 3 merge); `admin` overrides only the memory limit.

Before applying, create the images, the `shop-runtime` service account, the connector and the secrets, and grant the service account `roles/secretmanager.secretAccessor` on the secrets.
