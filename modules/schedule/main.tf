# -----------------------------------------------------------------------------
# One Cloud Scheduler job with an HTTP target, authenticated with an OAuth
# token (Google APIs, e.g. to execute a Cloud Run job) or an OIDC token (e.g.
# to call a Cloud Run service). modules/service and modules/job use it for
# their `schedules`.
# -----------------------------------------------------------------------------

resource "google_cloud_scheduler_job" "this" {
  name             = var.name
  project          = var.project_id
  region           = var.region
  description      = var.description
  schedule         = var.schedule
  time_zone        = var.time_zone
  paused           = var.paused
  attempt_deadline = var.attempt_deadline

  dynamic "retry_config" {
    for_each = var.retry_config == null ? [] : [var.retry_config]
    content {
      retry_count          = retry_config.value.retry_count
      max_retry_duration   = retry_config.value.max_retry_duration
      min_backoff_duration = retry_config.value.min_backoff_duration
      max_backoff_duration = retry_config.value.max_backoff_duration
      max_doublings        = retry_config.value.max_doublings
    }
  }

  http_target {
    uri         = var.uri
    http_method = var.http_method
    headers     = length(var.headers) == 0 ? null : var.headers
    body        = var.body == null ? null : base64encode(var.body)

    dynamic "oauth_token" {
      for_each = var.oauth_token == null ? [] : [var.oauth_token]
      content {
        service_account_email = oauth_token.value.service_account_email
        scope                 = oauth_token.value.scope
      }
    }

    dynamic "oidc_token" {
      for_each = var.oidc_token == null ? [] : [var.oidc_token]
      content {
        service_account_email = oidc_token.value.service_account_email
        audience              = oidc_token.value.audience
      }
    }
  }

  lifecycle {
    precondition {
      condition     = (var.oauth_token == null) != (var.oidc_token == null)
      error_message = "Set exactly one of oauth_token and oidc_token."
    }
  }
}
