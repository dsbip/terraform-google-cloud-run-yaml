variable "config_file" {
  description = <<-EOT
    Path to the YAML configuration file. The file is rendered with templatefile()
    before it is parsed, so $${name} placeholders are replaced with values from
    template_vars (project_id and region are always available). Write $$${ in the
    file to get a literal $${. Exactly one of config_file and config_yaml must be set.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.config_file == null || try(fileexists(var.config_file), false)
    error_message = "The config_file variable must point to an existing file."
  }
}

variable "config_yaml" {
  description = <<-EOT
    YAML configuration as a string, e.g. yamlencode({...}) or the output of your
    own templatefile() call. It is used as-is (not template-rendered).
    Exactly one of config_file and config_yaml must be set.
  EOT
  type        = string
  default     = null
}

variable "template_vars" {
  description = "Values for $${...} placeholders in config_file. project_id and region are added automatically. Values must be known at plan time."
  type        = any
  default     = {}

  validation {
    condition     = can(merge({}, var.template_vars))
    error_message = "The template_vars variable must be a map or object."
  }
}

variable "project_id" {
  description = "Default project for every service and job. Used when the YAML has no top-level project_id; resource-level project_id values take precedence over both."
  type        = string
  default     = null
}

variable "region" {
  description = "Default region for every service and job. Used when the YAML has no defaults.region; resource-level region values take precedence over both."
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels added to every service and job. YAML labels with the same key take precedence."
  type        = map(string)
  default     = {}
  nullable    = false
}
