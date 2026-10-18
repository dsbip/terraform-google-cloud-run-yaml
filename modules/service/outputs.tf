output "id" {
  description = "Service ID (projects/P/locations/R/services/NAME)."
  value       = google_cloud_run_v2_service.this.id
}

output "name" {
  description = "Service name."
  value       = google_cloud_run_v2_service.this.name
}

output "project_id" {
  description = "Project of the service."
  value       = var.project_id
}

output "region" {
  description = "Region of the service."
  value       = var.region
}

output "uri" {
  description = "Main URI of the service (https://NAME-HASH-REGION.a.run.app)."
  value       = google_cloud_run_v2_service.this.uri
}

output "urls" {
  description = "All URLs of the service."
  value       = google_cloud_run_v2_service.this.urls
}

output "latest_ready_revision" {
  description = "Name of the latest revision that is serving."
  value       = google_cloud_run_v2_service.this.latest_ready_revision
}

output "service_account" {
  description = "Runtime service account of new revisions."
  value       = google_cloud_run_v2_service.this.template[0].service_account
}

output "schedules" {
  description = "Cloud Scheduler job names, keyed by schedule key."
  value       = { for k, m in module.schedule : k => m.name }
}

output "invoker_members" {
  description = "Members granted roles/run.invoker."
  value       = sort(keys(google_cloud_run_v2_service_iam_member.invoker))
}

output "iam_members" {
  description = "IAM grants as \"ROLE MEMBER\" (with \" [CONDITION TITLE]\" for conditional grants)."
  value       = sort(keys(google_cloud_run_v2_service_iam_member.this))
}

output "service" {
  description = "The google_cloud_run_v2_service resource, for attributes not exposed above."
  value       = google_cloud_run_v2_service.this
}

output "scheduler_jobs" {
  description = "The google_cloud_scheduler_job resources, keyed by schedule key."
  value       = { for k, m in module.schedule : k => m.job }
}
