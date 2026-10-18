output "id" {
  description = "Job ID (projects/P/locations/R/jobs/NAME)."
  value       = google_cloud_run_v2_job.this.id
}

output "name" {
  description = "Job name."
  value       = google_cloud_run_v2_job.this.name
}

output "project_id" {
  description = "Project of the job."
  value       = var.project_id
}

output "region" {
  description = "Region of the job."
  value       = var.region
}

output "run_uri" {
  description = "Cloud Run Admin API URI that executes the job (POST)."
  value       = local.run_uri
}

output "latest_created_execution" {
  description = "Latest execution of the job, if any."
  value       = try(google_cloud_run_v2_job.this.latest_created_execution[0].name, null)
}

output "service_account" {
  description = "Runtime service account of the tasks."
  value       = google_cloud_run_v2_job.this.template[0].template[0].service_account
}

output "schedules" {
  description = "Cloud Scheduler job names, keyed by schedule key."
  value       = { for k, m in module.schedule : k => m.name }
}

output "invoker_members" {
  description = "Members granted roles/run.invoker."
  value       = sort(keys(google_cloud_run_v2_job_iam_member.invoker))
}

output "iam_members" {
  description = "IAM grants as \"ROLE MEMBER\" (with \" [CONDITION TITLE]\" for conditional grants)."
  value       = sort(keys(google_cloud_run_v2_job_iam_member.this))
}

output "job" {
  description = "The google_cloud_run_v2_job resource, for attributes not exposed above."
  value       = google_cloud_run_v2_job.this
}

output "scheduler_jobs" {
  description = "The google_cloud_scheduler_job resources, keyed by schedule key."
  value       = { for k, m in module.schedule : k => m.job }
}
