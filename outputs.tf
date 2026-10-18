output "services" {
  description = "Deployed services keyed by YAML key: id, name, project_id, region, uri, urls, latest_ready_revision, service_account and schedules."
  value = {
    for k, m in module.service : k => {
      id                    = m.id
      name                  = m.name
      project_id            = m.project_id
      region                = m.region
      uri                   = m.uri
      urls                  = m.urls
      latest_ready_revision = m.latest_ready_revision
      service_account       = m.service_account
      schedules             = m.schedules
    }
  }
}

output "jobs" {
  description = "Deployed jobs keyed by YAML key: id, name, project_id, region, run_uri, latest_created_execution, service_account and schedules."
  value = {
    for k, m in module.job : k => {
      id                       = m.id
      name                     = m.name
      project_id               = m.project_id
      region                   = m.region
      run_uri                  = m.run_uri
      latest_created_execution = m.latest_created_execution
      service_account          = m.service_account
      schedules                = m.schedules
    }
  }
}

output "service_uris" {
  description = "Main URI of every service, keyed by YAML key."
  value       = { for k, m in module.service : k => m.uri }
}

output "config" {
  description = "The normalised configuration (after defaults), as { services = {...}, jobs = {...} }, including disabled entries."
  value       = { services = local.services, jobs = local.jobs }
}
