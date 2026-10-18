variable "name" {
  description = "Cloud Scheduler job name: letters, digits, hyphens and underscores."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,500}$", var.name))
    error_message = "The name may contain only letters, digits, hyphens and underscores (at most 500)."
  }
}

variable "project_id" {
  description = "Project of the scheduler job."
  type        = string
}

variable "region" {
  description = "Cloud Scheduler region."
  type        = string
}

variable "schedule" {
  description = "Cron schedule, e.g. \"0 2 * * *\"."
  type        = string
}

variable "time_zone" {
  description = "Time zone of the schedule (tz database name). Null: UTC."
  type        = string
  default     = null
}

variable "description" {
  description = "Description."
  type        = string
  default     = null
}

variable "paused" {
  description = "Create the job paused."
  type        = bool
  default     = null
}

variable "attempt_deadline" {
  description = "Deadline per attempt, e.g. 320s."
  type        = string
  default     = null
}

variable "retry_config" {
  description = "Retries of failed attempts."
  type = object({
    retry_count          = optional(number)
    max_retry_duration   = optional(string)
    min_backoff_duration = optional(string)
    max_backoff_duration = optional(string)
    max_doublings        = optional(number)
  })
  default = null
}

variable "uri" {
  description = "URI to call."
  type        = string
}

variable "http_method" {
  description = "HTTP method."
  type        = string
  default     = "POST"
  nullable    = false

  validation {
    condition     = contains(["POST", "GET", "HEAD", "PUT", "DELETE", "PATCH", "OPTIONS"], var.http_method)
    error_message = "The http_method must be POST, GET, HEAD, PUT, DELETE, PATCH or OPTIONS."
  }
}

variable "headers" {
  description = "Request headers."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "body" {
  description = "Request body as plain text (base64-encoded by the module)."
  type        = string
  default     = null
}

variable "oauth_token" {
  description = "OAuth token for Google APIs (e.g. run.googleapis.com). Set this or oidc_token."
  type = object({
    service_account_email = string
    scope                 = optional(string, "https://www.googleapis.com/auth/cloud-platform")
  })
  default = null
}

variable "oidc_token" {
  description = "OIDC ID token for services such as Cloud Run (audience: the service URL by default). Set this or oauth_token."
  type = object({
    service_account_email = string
    audience              = optional(string)
  })
  default = null
}
