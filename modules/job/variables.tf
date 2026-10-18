variable "name" {
  description = "Job name: lowercase letters, digits and hyphens, starting with a letter, at most 63 characters."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.name))
    error_message = "The name must start with a lowercase letter, contain only lowercase letters, digits and hyphens, not end with a hyphen, and be at most 63 characters long."
  }
}

variable "project_id" {
  description = "Project of the job."
  type        = string
}

variable "region" {
  description = "Region of the job, e.g. europe-west1."
  type        = string
}

variable "labels" {
  description = "Job labels."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "annotations" {
  description = "Job annotations."
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

variable "launch_stage" {
  description = "GA, BETA or ALPHA (needed for preview features)."
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Whether Terraform may delete the job. Null keeps the provider default (true: protected)."
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

variable "binary_authorization" {
  description = "Binary Authorization: { use_default, policy, breakglass_justification }."
  type = object({
    use_default              = optional(bool)
    policy                   = optional(string)
    breakglass_justification = optional(string)
  })
  default = null
}

variable "start_execution_token" {
  description = "Changing this value starts an execution on create/update (apply waits until it has started)."
  type        = string
  default     = null
}

variable "run_execution_token" {
  description = "Changing this value runs an execution on create/update (apply waits until it has completed)."
  type        = string
  default     = null
}

variable "template" {
  description = <<-EOT
    What an execution runs: the provider's execution template (labels,
    annotations, parallelism, task_count) and task template (containers,
    volumes, max_retries, timeout, service_account, ...) in one object.
    Containers take `env` and `secret_env` (NAME = { secret, version = "latest" }) maps.
  EOT
  type = object({
    labels                        = optional(map(string))
    annotations                   = optional(map(string))
    parallelism                   = optional(number)
    task_count                    = optional(number)
    max_retries                   = optional(number)
    timeout                       = optional(string)
    service_account               = optional(string)
    execution_environment         = optional(string)
    encryption_key                = optional(string)
    gpu_zonal_redundancy_disabled = optional(bool)
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
      name        = optional(string)
      image       = string
      command     = optional(list(string))
      args        = optional(list(string))
      working_dir = optional(string)
      depends_on  = optional(list(string))
      env         = optional(map(string), {})
      secret_env = optional(map(object({
        secret  = string
        version = optional(string, "latest")
      })), {})
      resources = optional(object({
        limits = optional(map(string))
      }))
      volume_mounts = optional(list(object({
        name       = string
        mount_path = string
        sub_path   = optional(string)
      })), [])
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
    }))
    volumes = optional(list(object({
      name = string
      secret = optional(object({
        secret       = string
        default_mode = optional(number)
        items = optional(list(object({
          path    = string
          version = optional(string, "latest")
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
    condition = alltrue(flatten([
      for c in var.template.containers : [
        for p in [c.startup_probe] : length([for h in [try(p.http_get, null), try(p.tcp_socket, null), try(p.grpc, null)] : h if h != null]) <= 1 if p != null
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

variable "invokers" {
  description = "Members granted roles/run.invoker on the job (allowed to execute it)."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "iam" {
  description = "Additional IAM grants on the job (non-authoritative)."
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
  description = "Cloud Scheduler jobs that execute the job, keyed by name (scheduler job name: <job>-<key>). Calls use an OAuth token of service_account_email."
  type = map(object({
    schedule              = string
    service_account_email = string
    time_zone             = optional(string)
    description           = optional(string)
    paused                = optional(bool)
    region                = optional(string)
    attempt_deadline      = optional(string)
    retry_config = optional(object({
      retry_count          = optional(number)
      max_retry_duration   = optional(string)
      min_backoff_duration = optional(string)
      max_backoff_duration = optional(string)
      max_doublings        = optional(number)
    }))
    overrides = optional(object({
      container  = optional(string)
      args       = optional(list(string))
      env        = optional(map(string))
      task_count = optional(number)
      timeout    = optional(string)
    }))
  }))
  default  = {}
  nullable = false
}
