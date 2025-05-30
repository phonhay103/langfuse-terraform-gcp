# TLS Certificate
resource "google_compute_managed_ssl_certificate" "this" {
  count = var.domain != null ? 1 : 0
  name  = var.name

  managed {
    domains = [var.domain]
  }
}

# Frontend config for HTTPs redirect
resource "kubernetes_manifest" "https_redirect" {
  count = var.domain != null ? 1 : 0
  manifest = {
    "apiVersion" = "networking.gke.io/v1beta1"
    "kind"       = "FrontendConfig"
    "metadata" = {
      "name"      = "https-redirect"
      "namespace" = kubernetes_namespace.langfuse.metadata[0].name
    }
    "spec" = {
      "redirectToHttps" = {
        enabled          = "true"
        responseCodeName = "PERMANENT_REDIRECT"
      }
    }
  }
}
