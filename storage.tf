locals {
  # Convert domain to bucket-friendly format (e.g., company.com -> company-com)
  # If domain is not provided, use a default prefix
  bucket_prefix = var.domain != null ? replace(var.domain, ".", "-") : "langfuse-storage"
}

resource "google_storage_bucket" "langfuse" {
  name                        = "${local.bucket_prefix}-${var.name}"
  location                    = data.google_client_config.current.region
  force_destroy               = !var.deletion_protection
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }
}

# Allow all access on bucket for langfuse user
resource "google_storage_bucket_iam_binding" "langfuse" {
  for_each = toset([
    "storage.admin",
    "storage.objectAdmin",
  ])

  bucket = google_storage_bucket.langfuse.name
  role   = "roles/${each.value}"
  members = [
    "serviceAccount:${google_service_account.langfuse.email}",
  ]
}

resource "google_storage_hmac_key" "langfuse" {
  service_account_email = google_service_account.langfuse.email
}
