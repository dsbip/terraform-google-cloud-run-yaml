# One modules/job instance per enabled job (empty while the configuration has
# problems, see services.tf).
module "job" {
  source   = "./modules/job"
  for_each = { for k, j in local.jobs : k => j if j.enabled && local.config_valid }

  name                  = each.value.name
  project_id            = each.value.project_id
  region                = each.value.region
  labels                = each.value.labels
  annotations           = each.value.annotations
  client                = each.value.client
  client_version        = each.value.client_version
  launch_stage          = each.value.launch_stage
  deletion_protection   = each.value.deletion_protection
  deletion_policy       = each.value.deletion_policy
  binary_authorization  = each.value.binary_authorization
  start_execution_token = each.value.start_execution_token
  run_execution_token   = each.value.run_execution_token
  template              = each.value.template
  invokers              = each.value.invokers
  iam                   = each.value.iam
  schedules             = each.value.schedules
}
