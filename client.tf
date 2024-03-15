# Create a storage bucket
resource "google_storage_bucket" "client_site_bucket" {
  name     = "${var.project_name}-bucket"
  location = "US"

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
}

# Make the bucket publicly accessible
resource "google_storage_bucket_iam_member" "client_public_read" {
  bucket = google_storage_bucket.client_site_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Allow the client site svc account write access to the bucket
resource "google_storage_bucket_iam_binding" "client_svc_writer" {
  bucket = google_storage_bucket.client_site_bucket.name
  role   = "roles/storage.objectAdmin"
  members = [
    "serviceAccount:${var.client_site_service_account_email}",
  ]
}

# Load balancer and CDN for client site bucket
resource "google_compute_backend_bucket" "client_backend_bucket" {
  name        = "${var.project_name}-client-bucket"
  bucket_name = google_storage_bucket.client_site_bucket.name
  enable_cdn  = true
}

resource "google_compute_url_map" "client" {
  name            = "${var.project_name}-client-url-map"
  default_service = google_compute_backend_bucket.client_backend_bucket.self_link
}

resource "google_compute_target_http_proxy" "client" {
  name    = "${var.project_name}-client-http-proxy"
  url_map = google_compute_url_map.client.self_link
}

resource "google_compute_global_address" "client" {
  name = "client-static-ip"
}

resource "google_compute_global_forwarding_rule" "client" {
  name       = "${var.project_name}-client-forwarding-rule"
  target     = google_compute_target_http_proxy.client.self_link
  ip_address = google_compute_global_address.client.address
  port_range = "80"
}