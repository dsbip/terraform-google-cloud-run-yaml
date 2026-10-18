variable "name" {
  description = "Service name: lowercase letters, digits and hyphens, starting with a letter, at most 49 characters."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,47}[a-z0-9])?$", var.name))
    error_message = "The name must start with a lowercase letter, contain only lowercase letters, digits and hyphens, not end with a hyphen, and be at most 49 characters long."
  }
}

variable "project_id" {
  description = "Project of the service."
  type        = string
}

variable "region" {
  description = "Region of the service, e.g. europe-west1."
  type        = string
}

variable "description" {
  description = "Description."
  type        = string
  default     = null
}

variable "labels" {
  description = "Service labels."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "annotations" {
  description = "Service annotations."
  type        = map(string)
  default     = null
}

variable "client" {
  description = "Name of the deploying client."
  type        = string
  default     = null
}

variable "client_version" {
  description = "Version of the deploying client."
  type        = string
  default     = null
}

variable "ingress" {
  description = "INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY or INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER."
  type        = string
  default     = null

  validation {
    condition     = var.ingress == null || contains(["INGRESS_TRAFFIC_ALL", "INGRESS_TRAFFIC_INTERNAL_ONLY", "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"], coalesce(var.ingress, "INGRESS_TRAFFIC_ALL"))
    error_message = "The ingress must be INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY or INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER."
  }
}

variable "launch_stage" {
  description = "GA, BETA or ALPHA (needed for preview features)."
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Whether Terraform may delete the service. Null keeps the provider default (true: protected)."
  type        = bool
  default     = null
}

variable "deletion_policy" {
  description = "DELETE, PREVENT or ABANDON."
  type        = string
  default     = null

  validation {
    condition     = var.deletion_policy == null || contains(["DELETE", "PREVENT", "ABANDON"], coalesce(var.deletion_policy, "DELETE"))
    error_message = "The deletion_policy must be DELETE, PREVENT or ABANDON."
  }
}

variable "custom_audiences" {
  description = "Extra audiences accepted in ID tokens."
  type        = list(string)
  default     = null
}

variable "default_uri_disabled" {
  description = "Disable the run.app URL."
  type        = bool
  default     = null
}

variable "invoker_iam_disabled" {
  description = "Skip the IAM invoker check (public service without allUsers)."
  type        = bool
  default     = null
}

variable "iap_enabled" {
  description = "Enable Identity-Aware Proxy."
  type        = bool
  default     = null
}

variable "binary_authorization" {
  description = "Binary Authorization: { use_default, policy, breakglass_justification }."
  type = object({
    use_default              = optional(bool)
    policy                   = optional(string)
    breakglass_justification = optional(string)
  })
  default = null
}

variable "scaling" {
  description = "Service-level scaling: { min_instance_count, max_instance_count, manual_instance_count, scaling_mode }."
  type = object({
    min_instance_count    = optional(number)
    max_instance_count    = optional(number)
    manual_instance_count = optional(number)
    scaling_mode          = optional(string)
  })
  default = null

  validation {
    condition     = try(var.scaling.scaling_mode != "MANUAL" || var.scaling.manual_instance_count != null, true)
    error_message = "The scaling_mode MANUAL needs scaling.manual_instance_count."
  }
}

variable "template" {
  description = <<-EOT
    Revision template. Containers take `env` (plain variables) and `secret_env`
    (NAME = { secret, version = "latest" }) as maps; everything else mirrors the
    provider's template block. Single-element blocks (scaling, vpc_access,
    node_selector, resources, ports, probes, volume kinds) are objects.
  EOT
  type = object({
    revision                         = optional(string)
    labels                           = optional(map(string))
    annotations                      = optional(map(string))
    timeout                          = optional(string)
    service_account                  = optional(string)
    execution_environment            = optional(string)
    encryption_key                   = optional(string)
    max_instance_request_concurrency = optional(number)
    session_affinity                 = optional(bool)
    gpu_zonal_redundancy_disabled    = optional(bool)
    health_check_disabled            = optional(bool)
    scaling = optional(object({
      min_instance_count = optional(number)
      max_instance_count = optional(number)
    }))
    vpc_access = optional(object({
      connector = optional(string)
      egress    = optional(string)
      network_interfaces = optional(list(object({
        network    = optional(string)
        subnetwork = optional(string)
        tags       = optional(list(string))
      })), [])
    }))
    node_selector = optional(object({
      accelerator = string
    }))
    containers = list(object({
      name           = optional(string)
      image          = string
      command        = optional(list(string))
      args           = optional(list(string))
      working_dir    = optional(string)
      depends_on     = optional(list(string))
      base_image_uri = optional(string)
      env            = optional(map(string), {})
      secret_env = optional(map(object({
        secret  = string
        version = optional(string, "latest")
      })), {})
      resources = optional(object({
        limits            = optional(map(string))
        cpu_idle          = optional(bool)
        startup_cpu_boost = optional(bool)
      }))
      ports = optional(object({
        container_port = optional(number)
        name           = optional(string)
      }))
      volume_mounts = optional(list(object({
        name       = string
        mount_path = string
        sub_path   = optional(string)
      })), [])
      liveness_probe = optional(object({
        initial_delay_seconds = optional(number)
        timeout_seconds       = optional(number)
        period_seconds        = optional(number)
        failure_threshold     = optional(number)
        http_get = optional(object({
          path         = optional(string)
          port         = optional(number)
          http_headers = optional(list(object({ name = string, value = optional(string) })), [])
        }))
        tcp_socket = optional(object({ port = optional(number) }))
        grpc       = optional(object({ port = optional(number), service = optional(string) }))
      }))
      startup_probe = optional(object({
        initial_delay_seconds = optional(number)
        timeout_seconds       = optional(number)
        period_seconds        = optional(number)
        failure_threshold     = optional(number)
        http_get = optional(object({
          path         = optional(string)
          port         = optional(number)
          http_headers = optional(list(object({ name = string, value = optional(string) })), [])
        }))
        tcp_socket = optional(object({ port = optional(number) }))
        grpc       = optional(object({ port = optional(number), service = optional(string) }))
      }))
      readiness_probe = optional(object({
        failure_threshold = optional(number)
        success_threshold = optional(number)
        period_seconds    = optional(number)
        timeout_seconds   = optional(number)
        http_get          = optional(object({ path = optional(string), port = optional(number) }))
        grpc              = optional(object({ port = optional(number), service = optional(string) }))
      }))
    }))
    volumes = optional(list(object({
      name = string
      secret = optional(object({
        secret       = string
        default_mode = optional(number)
        items = optional(list(object({
          path    = string
          version = optional(string)
          mode    = optional(number)
        })), [])
      }))
      cloud_sql_instance = optional(object({ instances = list(string) }))
      empty_dir          = optional(object({ medium = optional(string), size_limit = optional(string) }))
      gcs                = optional(object({ bucket = string, read_only = optional(bool), mount_options = optional(list(string)) }))
      nfs                = optional(object({ server = string, path = optional(string), read_only = optional(bool) }))
    })), [])
  })

  validation {
    condition     = length(var.template.containers) > 0
    error_message = "The template needs at least one container."
  }

  validation {
    condition     = length(var.template.containers) == 1 || length([for c in var.template.containers : c if c.ports != null]) == 1
    error_message = "With several containers, exactly one (the ingress container) must set ports."
  }

  validation {
    condition = alltrue(flatten([
      for c in var.template.containers : [
        for p in [c.startup_probe, c.liveness_probe, c.readiness_probe] : length([for h in [try(p.http_get, null), try(p.tcp_socket, null), try(p.grpc, null)] : h if h != null]) <= 1 if p != null
      ]
    ]))
    error_message = "A probe may set only one of http_get, tcp_socket and grpc."
  }

  validation {
    condition = alltrue([
      for v in var.template.volumes : length([for kind in [v.secret, v.cloud_sql_instance, v.empty_dir, v.gcs, v.nfs] : kind if kind != null]) == 1
    ])
    error_message = "Each volume must set exactly one of secret, cloud_sql_instance, empty_dir, gcs and nfs."
  }
}

variable "traffic" {
  description = "Traffic targets: { type = LATEST|REVISION (or the long provider forms), revision, percent, tag }. Empty: the provider default (100% to the latest revision)."
  type = list(object({
    type     = optional(string)
    revision = optional(string)
    percent  = optional(number)
    tag      = optional(string)
  }))
  default  = []
  nullable = false
}

variable "invokers" {
  description = "Members granted roles/run.invoker on the service."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "iam" {
  description = "Additional IAM grants on the service (non-authoritative)."
  type = list(object({
    role    = string
    members = list(string)
    condition = optional(object({
      title       = string
      expression  = string
      description = optional(string)
    }))
  }))
  default  = []
  nullable = false
}

variable "schedules" {
  description = "Cloud Scheduler jobs that call the service, keyed by name (scheduler job name: <service>-<key>). Calls use an OIDC token of service_account_email."
  type = map(object({
    schedule              = string
    service_account_email = string
    time_zone             = optional(string)
    description           = optional(string)
    paused                = optional(bool)
    region                = optional(string)
    path                  = optional(string, "/")
    http_method           = optional(string, "POST")
    headers               = optional(map(string), {})
    body                  = optional(string)
    audience              = optional(string)
    attempt_deadline      = optional(string)
    retry_config = optional(object({
      retry_count          = optional(number)
      max_retry_duration   = optional(string)
      min_backoff_duration = optional(string)
      max_backoff_duration = optional(string)
      max_doublings        = optional(number)
    }))
  }))
  default  = {}
  nullable = false
}
