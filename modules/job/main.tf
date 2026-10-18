# -----------------------------------------------------------------------------
# One Cloud Run job with its invoker grants, IAM and schedules. Usable on its
# own; the YAML root module calls it once per job.
# -----------------------------------------------------------------------------

locals {
  # One grant per (role, member, condition); see modules/service.
  iam_members = {
    for key, grants in {
      for g in flatten([
        for b in var.iam : [for m in b.members : { role = b.role, member = m, condition = b.condition }]
      ]) : "${g.role} ${g.member}${g.condition == null ? "" : " [${g.condition.title}]"}" => g...
    } : key => grants[0]
    if !(grants[0].role == "roles/run.invoker" && grants[0].condition == null && contains(var.invokers, grants[0].member))
  }

  run_uri = "https://run.googleapis.com/v2/projects/${var.project_id}/locations/${var.region}/jobs/${var.name}:run"

  # RunJobRequest bodies (https://cloud.google.com/run/docs/reference/rest/v2/projects.locations.jobs/run).
  # A schedule without overrides runs the job as configured. Unset fields are
  # filtered out rather than chosen with conditionals, because the branches
  # would be objects of different types.
  run_bodies = {
    for k, s in var.schedules : k => s.overrides == null ? null : jsonencode({
      overrides = {
        for field, value in {
          containerOverrides = [{
            for ck, cv in {
              name = try(coalesce(s.overrides.container, var.template.containers[0].name), null)
              args = s.overrides.args
              env  = s.overrides.env == null ? null : [for n, v in s.overrides.env : { name = n, value = v }]
            } : ck => cv if cv != null
          }]
          taskCount = s.overrides.task_count
          timeout   = s.overrides.timeout
        } : field => value
        if value != null && (field != "containerOverrides" || s.overrides.args != null || s.overrides.env != null)
      }
    })
  }
}

resource "google_cloud_run_v2_job" "this" {
  name                  = var.name
  project               = var.project_id
  location              = var.region
  labels                = var.labels
  annotations           = var.annotations
  client                = var.client
  client_version        = var.client_version
  launch_stage          = var.launch_stage
  deletion_protection   = var.deletion_protection
  deletion_policy       = var.deletion_policy
  start_execution_token = var.start_execution_token
  run_execution_token   = var.run_execution_token

  dynamic "binary_authorization" {
    for_each = var.binary_authorization == null ? [] : [var.binary_authorization]
    content {
      use_default              = binary_authorization.value.use_default
      policy                   = binary_authorization.value.policy
      breakglass_justification = binary_authorization.value.breakglass_justification
    }
  }

  template {
    labels      = var.template.labels
    annotations = var.template.annotations
    parallelism = var.template.parallelism
    task_count  = var.template.task_count

    template {
      max_retries                   = var.template.max_retries
      timeout                       = var.template.timeout
      service_account               = var.template.service_account
      execution_environment         = var.template.execution_environment
      encryption_key                = var.template.encryption_key
      gpu_zonal_redundancy_disabled = var.template.gpu_zonal_redundancy_disabled

      dynamic "vpc_access" {
        for_each = var.template.vpc_access == null ? [] : [var.template.vpc_access]
        content {
          connector = vpc_access.value.connector
          egress    = vpc_access.value.egress

          dynamic "network_interfaces" {
            for_each = vpc_access.value.network_interfaces
            content {
              network    = network_interfaces.value.network
              subnetwork = network_interfaces.value.subnetwork
              tags       = network_interfaces.value.tags
            }
          }
        }
      }

      dynamic "node_selector" {
        for_each = var.template.node_selector == null ? [] : [var.template.node_selector]
        content {
          accelerator = node_selector.value.accelerator
        }
      }

      dynamic "containers" {
        for_each = var.template.containers
        content {
          name        = containers.value.name
          image       = containers.value.image
          command     = containers.value.command
          args        = containers.value.args
          working_dir = containers.value.working_dir
          depends_on  = containers.value.depends_on

          dynamic "env" {
            for_each = containers.value.env
            content {
              name  = env.key
              value = env.value
            }
          }

          dynamic "env" {
            for_each = containers.value.secret_env
            content {
              name = env.key
              value_source {
                secret_key_ref {
                  secret  = env.value.secret
                  version = env.value.version
                }
              }
            }
          }

          dynamic "resources" {
            for_each = containers.value.resources == null ? [] : [containers.value.resources]
            content {
              limits = resources.value.limits
            }
          }

          dynamic "volume_mounts" {
            for_each = containers.value.volume_mounts
            content {
              name       = volume_mounts.value.name
              mount_path = volume_mounts.value.mount_path
              sub_path   = volume_mounts.value.sub_path
            }
          }

          dynamic "startup_probe" {
            for_each = containers.value.startup_probe == null ? [] : [containers.value.startup_probe]
            content {
              initial_delay_seconds = startup_probe.value.initial_delay_seconds
              timeout_seconds       = startup_probe.value.timeout_seconds
              period_seconds        = startup_probe.value.period_seconds
              failure_threshold     = startup_probe.value.failure_threshold

              dynamic "http_get" {
                for_each = startup_probe.value.http_get == null ? [] : [startup_probe.value.http_get]
                content {
                  path = http_get.value.path
                  port = http_get.value.port

                  dynamic "http_headers" {
                    for_each = http_get.value.http_headers
                    content {
                      name  = http_headers.value.name
                      value = http_headers.value.value
                    }
                  }
                }
              }

              dynamic "tcp_socket" {
                for_each = startup_probe.value.tcp_socket == null ? [] : [startup_probe.value.tcp_socket]
                content {
                  port = tcp_socket.value.port
                }
              }

              dynamic "grpc" {
                for_each = startup_probe.value.grpc == null ? [] : [startup_probe.value.grpc]
                content {
                  port    = grpc.value.port
                  service = grpc.value.service
                }
              }
            }
          }
        }
      }

      dynamic "volumes" {
        for_each = var.template.volumes
        content {
          name = volumes.value.name

          dynamic "secret" {
            for_each = volumes.value.secret == null ? [] : [volumes.value.secret]
            content {
              secret       = secret.value.secret
              default_mode = secret.value.default_mode

              dynamic "items" {
                for_each = secret.value.items
                content {
                  path    = items.value.path
                  version = items.value.version
                  mode    = items.value.mode
                }
              }
            }
          }

          dynamic "cloud_sql_instance" {
            for_each = volumes.value.cloud_sql_instance == null ? [] : [volumes.value.cloud_sql_instance]
            content {
              instances = cloud_sql_instance.value.instances
            }
          }

          dynamic "empty_dir" {
            for_each = volumes.value.empty_dir == null ? [] : [volumes.value.empty_dir]
            content {
              medium     = empty_dir.value.medium
              size_limit = empty_dir.value.size_limit
            }
          }

          dynamic "gcs" {
            for_each = volumes.value.gcs == null ? [] : [volumes.value.gcs]
            content {
              bucket        = gcs.value.bucket
              read_only     = gcs.value.read_only
              mount_options = gcs.value.mount_options
            }
          }

          dynamic "nfs" {
            for_each = volumes.value.nfs == null ? [] : [volumes.value.nfs]
            content {
              server    = nfs.value.server
              path      = nfs.value.path
              read_only = nfs.value.read_only
            }
          }
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = var.start_execution_token == null || var.run_execution_token == null
      error_message = "Set start_execution_token or run_execution_token, not both."
    }
  }
}

resource "google_cloud_run_v2_job_iam_member" "invoker" {
  for_each = toset(var.invokers)

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.this.name
  role     = "roles/run.invoker"
  member   = each.value
}

resource "google_cloud_run_v2_job_iam_member" "this" {
  for_each = local.iam_members

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.this.name
  role     = each.value.role
  member   = each.value.member

  dynamic "condition" {
    for_each = each.value.condition == null ? [] : [each.value.condition]
    content {
      title       = condition.value.title
      expression  = condition.value.expression
      description = condition.value.description
    }
  }
}

module "schedule" {
  source   = "../schedule"
  for_each = var.schedules

  name             = "${var.name}-${each.key}"
  project_id       = var.project_id
  region           = coalesce(each.value.region, var.region)
  schedule         = each.value.schedule
  time_zone        = each.value.time_zone
  description      = each.value.description
  paused           = each.value.paused
  attempt_deadline = each.value.attempt_deadline
  retry_config     = each.value.retry_config

  # The URI is built from the job's name rather than read from the resource,
  # so it is known at plan time; depends_on orders creation after the job.
  uri         = local.run_uri
  http_method = "POST"
  headers     = local.run_bodies[each.key] == null ? {} : { "Content-Type" = "application/json" }
  body        = local.run_bodies[each.key]
  oauth_token = {
    service_account_email = each.value.service_account_email
  }

  depends_on = [google_cloud_run_v2_job.this]
}
