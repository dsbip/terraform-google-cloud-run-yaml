output "id" {
  description = "Scheduler job ID."
  value       = google_cloud_scheduler_job.this.id
}

output "name" {
  description = "Scheduler job name."
  value       = google_cloud_scheduler_job.this.name
}

output "state" {
  description = "Scheduler job state, e.g. ENABLED or PAUSED."
  value       = google_cloud_scheduler_job.this.state
}

output "job" {
  description = "The google_cloud_scheduler_job resource."
  value       = google_cloud_scheduler_job.this
}
