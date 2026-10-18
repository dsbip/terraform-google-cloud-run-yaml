# -----------------------------------------------------------------------------
# Configuration loading
#
# The YAML is decoded into plain objects, merged with its defaults and passed
# to one modules/service or modules/job instance per entry (services.tf,
# jobs.tf). Loading never fails on bad input: every lookup is wrapped in try()
# so that validation.tf can report all problems at once with YAML paths.
# -----------------------------------------------------------------------------

locals {
  # JSON Schema of the configuration file. validation.tf reads allowed keys,
  # types, enumerations, ranges and patterns from it.
  schema = jsondecode(file("${path.module}/schemas/cloud-run-config.schema.json"))

  config_template_vars = try(
    merge({ project_id = var.project_id, region = var.region }, var.template_vars),
    { project_id = var.project_id, region = var.region },
  )

  config_text = (
    var.config_yaml != null ? var.config_yaml :
    var.config_file != null ? templatefile(var.config_file, local.config_template_vars) :
    ""
  )

  # yamldecode() rejects documents that are empty or contain only comments.
  config_is_blank = length(regexall("(?m)^[ \\t]*[^#\\s]", local.config_text)) == 0
  config_decoded  = local.config_is_blank ? null : yamldecode(local.config_text)
  config          = try(merge({}, local.config_decoded), {})

  project_id = try(coalesce(try(tostring(local.config.project_id), null), var.project_id), null)
  defaults   = try(merge({}, local.config.defaults), {})
  region     = try(coalesce(try(tostring(local.defaults.region), null), var.region), null)
  labels     = merge(var.labels, try({ for k, v in local.defaults.labels : k => tostring(v) if v != null }, {}))

  # ---------------------------------------------------------------------------
  # Defaults
  #
  # defaults.services / defaults.jobs are merged underneath every service /
  # job, and defaults.service_container / defaults.job_container underneath
  # every container, three levels deep:
  #   level 1  keys of the entry       (template, ingress, env, resources, ...)
  #   level 2  keys of nested mappings (template.service_account, env.LOG_LEVEL,
  #                                     resources.limits, ...)
  #   level 3  keys inside those       (template.scaling.max_instance_count,
  #                                     resources.limits.memory, ...)
  # Lists (containers, volumes, invokers, ...) and scalars are replaced, never
  # concatenated. Explicit nulls are dropped first, so an empty `key:` line
  # never overrides a default. Keys that cannot be defaults are ignored here
  # and reported by validation.tf.
  # ---------------------------------------------------------------------------

  defaults_forbidden_keys = {
    for type in ["services", "jobs", "service_container", "job_container"] :
    type => try(local.schema.definitions.defaults.properties[type].allOf[1].propertyNames.not.enum, [])
  }

  type_defaults = {
    for type in ["services", "jobs", "service_container", "job_container"] : type => {
      for k, v in try(merge({}, local.defaults[type]), {}) : k => v
      if v != null && !contains(local.defaults_forbidden_keys[type], k)
    }
  }

  inputs = {
    services = try(merge({}, local.config.services), {})
    jobs     = try(merge({}, local.config.jobs), {})
  }

  inputs_clean = {
    for type, entries in local.inputs : type => {
      for key, e in entries : key => { for k, v in try(merge({}, e), {}) : k => v if v != null }
    }
  }

  merged = {
    for type, entries in local.inputs_clean : type => {
      for key, e in entries : key => {
        for k in setunion(keys(local.type_defaults[type]), keys(e)) : k => try(
          {
            for k2 in setunion(keys(local.type_defaults[type][k]), keys(e[k])) : k2 => try(
              merge(local.type_defaults[type][k][k2], e[k][k2]),
              [for v in [e[k][k2]] : v if v != null][0],
              local.type_defaults[type][k][k2],
            )
          },
          e[k],
          local.type_defaults[type][k],
        )
      }
    }
  }

  # Containers with the container defaults merged in (same three-level rule),
  # keyed by type, entry key and index.
  container_defaults = {
    services = local.type_defaults.service_container
    jobs     = local.type_defaults.job_container
  }

  containers = {
    for type, entries in local.merged : type => {
      for key, e in entries : key => [
        for c in try(concat(e.template.containers, []), []) : {
          for k in setunion(keys(local.container_defaults[type]), keys(try(merge({}, c), {}))) : k => try(
            {
              for k2 in setunion(keys(local.container_defaults[type][k]), keys(c[k])) : k2 => try(
                merge(local.container_defaults[type][k][k2], c[k][k2]),
                [for v in [c[k][k2]] : v if v != null][0],
                local.container_defaults[type][k][k2],
              )
            },
            [for v in [c[k]] : v if v != null][0],
            local.container_defaults[type][k],
          )
        }
      ]
    }
  }

  # Volumes with secret file modes as numbers: quoted octal strings ("0444")
  # are converted, numbers are kept. Volumes without a secret are unchanged.
  volumes = {
    for type, entries in local.merged : type => {
      for key, e in entries : key => [
        for v in try(concat(e.template.volumes, []), []) : merge(v, {
          for kind, s in { secret = try(v.secret, null) } : kind => merge(s, {
            default_mode = try(startswith(jsonencode(try(s.default_mode, null)), "\""), false) ? parseint(s.default_mode, 8) : try(s.default_mode, null)
            items = [
              for item in try(concat(s.items, []), []) : merge(item, {
                mode = try(startswith(jsonencode(try(item.mode, null)), "\""), false) ? parseint(item.mode, 8) : try(item.mode, null)
              })
            ]
          }) if s != null
        })
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # Normalised entries: exactly the inputs of modules/service and modules/job.
  # ---------------------------------------------------------------------------

  common = {
    for type, entries in local.merged : type => {
      for key, e in entries : key => {
        enabled              = try(tobool(e.enabled), true)
        name                 = try(tostring(e.name), key)
        project_id           = try(coalesce(try(tostring(e.project_id), null), local.project_id), null)
        region               = try(coalesce(try(tostring(e.region), null), local.region), null)
        labels               = merge(local.labels, try({ for k, v in e.labels : k => tostring(v) if v != null }, {}))
        annotations          = try(e.annotations, null)
        client               = try(tostring(e.client), null)
        client_version       = try(tostring(e.client_version), null)
        launch_stage         = try(tostring(e.launch_stage), null)
        deletion_protection  = try(tobool(e.deletion_protection), null)
        deletion_policy      = try(tostring(e.deletion_policy), null)
        binary_authorization = try(e.binary_authorization, null)
        template             = try(merge(e.template, { containers = local.containers[type][key], volumes = local.volumes[type][key] }), try(e.template, null))
        invokers             = try(e.invokers, [])
        iam                  = try(e.iam, [])
        schedules            = try(e.schedules, {})
      }
    }
  }

  services = {
    for key, e in local.merged.services : key => merge(local.common.services[key], {
      description          = try(tostring(e.description), null)
      ingress              = try(tostring(e.ingress), null)
      custom_audiences     = try(e.custom_audiences, null)
      default_uri_disabled = try(tobool(e.default_uri_disabled), null)
      invoker_iam_disabled = try(tobool(e.invoker_iam_disabled), null)
      iap_enabled          = try(tobool(e.iap_enabled), null)
      scaling              = try(e.scaling, null)
      traffic              = try(e.traffic, [])
    })
  }

  jobs = {
    for key, e in local.merged.jobs : key => merge(local.common.jobs[key], {
      start_execution_token = try(tostring(e.start_execution_token), null)
      run_execution_token   = try(tostring(e.run_execution_token), null)
    })
  }
}
