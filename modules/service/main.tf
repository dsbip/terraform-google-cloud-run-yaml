# -----------------------------------------------------------------------------
# One Cloud Run service with its invoker grants, IAM and scheduled calls.
# Usable on its own; the YAML root module calls it once per service.
# -----------------------------------------------------------------------------

locals {
  traffic_types = {
    LATEST   = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    REVISION = "TRAFFIC_TARGET_ALLOCATION_TYPE_REVISION"
  }

  # One grant per (role, member, condition). Duplicates in the input collapse,
  # and unconditional run.invoker grants that `invokers` already makes are
  # skipped, so no two resources manage the same grant.
  iam_members = {
    for key, grants in {
      for g in flatten([
        for b in var.iam : [for m in b.members : { role = b.role, member = m, condition = b.condition }]
      ]) : "${g.role} ${g.member}${g.condition == null ? "" : " [${g.condition.title}]"}" => g...
    } : key => grants[0]
    if !(grants[0].role == "roles/run.invoker" && grants[0].condition == null && contains(var.invokers, grants[0].member))
  }
}

resource "google_cloud_run_v2_service" "this" {
  name                 = var.name
  project              = var.project_id
  location             = var.region
  description          = var.description
  labels               = var.labels
  annotations          = var.annotations
  client               = var.client
  client_version       = var.client_version
  ingress              = var.ingress
  launch_stage         = var.launch_stage
  deletion_protection  = var.deletion_protection
  deletion_policy      = var.deletion_policy
  custom_audiences     = var.custom_audiences
  default_uri_disabled = var.default_uri_disabled
  invoker_iam_disabled = var.invoker_iam_disabled
  iap_enabled          = var.iap_enabled

  dynamic "binary_authorization" {
    for_each = var.binary_authorization == null ? [] : [var.binary_authorization]
    content {
      use_default              = binary_authorization.value.use_default
      policy                   = binary_authorization.value.policy
      breakglass_justification = binary_authorization.value.breakglass_justification
    }
  }

  dynamic "scaling" {
    for_each = var.scaling == null ? [] : [var.scaling]
    content {
      min_instance_count    = scaling.value.min_instance_count
      max_instance_count    = scaling.value.max_instance_count
      manual_instance_count = scaling.value.manual_instance_count
      scaling_mode          = scaling.value.scaling_mode
    }
  }

  template {
    revision                         = var.template.revision
    labels                           = var.template.labels
    annotations                      = var.template.annotations
    timeout                          = var.template.timeout
    service_account                  = var.template.service_account
    execution_environment            = var.template.execution_environment
    encryption_key                   = var.template.encryption_key
    max_instance_request_concurrency = var.template.max_instance_request_concurrency
    session_affinity                 = var.template.session_affinity
    gpu_zonal_redundancy_disabled    = var.template.gpu_zonal_redundancy_disabled
    health_check_disabled            = var.template.health_check_disabled

    dynamic "scaling" {
      for_each = var.template.scaling == null ? [] : [var.template.scaling]
      content {
        min_instance_count = scaling.value.min_instance_count
        max_instance_count = scaling.value.max_instance_count
      }
    }

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
        name           = containers.value.name
        image          = containers.value.image
        command        = containers.value.command
        args           = containers.value.args
        working_dir    = containers.value.working_dir
        depends_on     = containers.value.depends_on
        base_image_uri = containers.value.base_image_uri

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
            limits            = resources.value.limits
            cpu_idle          = resources.value.cpu_idle
            startup_cpu_boost = resources.value.startup_cpu_boost
          }
        }

        dynamic "ports" {
          for_each = containers.value.ports == null ? [] : [containers.value.ports]
          content {
            container_port = ports.value.container_port
            name           = ports.value.name
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

        dynamic "liveness_probe" {
          for_each = containers.value.liveness_probe == null ? [] : [containers.value.liveness_probe]
          content {
            initial_delay_seconds = liveness_probe.value.initial_delay_seconds
            timeout_seconds       = liveness_probe.value.timeout_seconds
            period_seconds        = liveness_probe.value.period_seconds
            failure_threshold     = liveness_probe.value.failure_threshold

            dynamic "http_get" {
              for_each = liveness_probe.value.http_get == null ? [] : [liveness_probe.value.http_get]
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
              for_each = liveness_probe.value.tcp_socket == null ? [] : [liveness_probe.value.tcp_socket]
              content {
                port = tcp_socket.value.port
              }
            }

            dynamic "grpc" {
              for_each = liveness_probe.value.grpc == null ? [] : [liveness_probe.value.grpc]
              content {
                port    = grpc.value.port
                service = grpc.value.service
              }
            }
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

        dynamic "readiness_probe" {
          for_each = containers.value.readiness_probe == null ? [] : [containers.value.readiness_probe]
          content {
            failure_threshold = readiness_probe.value.failure_threshold
            success_threshold = readiness_probe.value.success_threshold
            period_seconds    = readiness_probe.value.period_seconds
            timeout_seconds   = readiness_probe.value.timeout_seconds

            dynamic "http_get" {
              for_each = readiness_probe.value.http_get == null ? [] : [readiness_probe.value.http_get]
              content {
                path = http_get.value.path
                port = http_get.value.port
              }
            }

            dynamic "grpc" {
              for_each = readiness_probe.value.grpc == null ? [] : [readiness_probe.value.grpc]
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

  dynamic "traffic" {
    for_each = var.traffic
    content {
      type     = traffic.value.type == null ? null : lookup(local.traffic_types, traffic.value.type, traffic.value.type)
      revision = traffic.value.revision
      percent  = traffic.value.percent
      tag      = traffic.value.tag
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  for_each = toset(var.invokers)

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = each.value
}

resource "google_cloud_run_v2_service_iam_member" "this" {
  for_each = local.iam_members

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.this.name
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

  uri         = "${google_cloud_run_v2_service.this.uri}${each.value.path}"
  http_method = each.value.http_method
  headers     = each.value.headers
  body        = each.value.body
  oidc_token = {
    service_account_email = each.value.service_account_email
    audience              = coalesce(each.value.audience, google_cloud_run_v2_service.this.uri)
  }
}
