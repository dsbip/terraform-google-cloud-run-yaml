# One modules/service instance per enabled service. The map is empty while the
# configuration has problems, so the plan fails with validation.tf's messages
# instead of type or provider errors.
module "service" {
  source   = "./modules/service"
  for_each = { for k, s in local.services : k => s if s.enabled && local.config_valid }

  name                 = each.value.name
  project_id           = each.value.project_id
  region               = each.value.region
  description          = each.value.description
  labels               = each.value.labels
  annotations          = each.value.annotations
  client               = each.value.client
  client_version       = each.value.client_version
  ingress              = each.value.ingress
  launch_stage         = each.value.launch_stage
  deletion_protection  = each.value.deletion_protection
  deletion_policy      = each.value.deletion_policy
  custom_audiences     = each.value.custom_audiences
  default_uri_disabled = each.value.default_uri_disabled
  invoker_iam_disabled = each.value.invoker_iam_disabled
  iap_enabled          = each.value.iap_enabled
  binary_authorization = each.value.binary_authorization
  scaling              = each.value.scaling
  template             = each.value.template
  traffic              = each.value.traffic
  invokers             = each.value.invokers
  iam                  = each.value.iam
  schedules            = each.value.schedules
}
