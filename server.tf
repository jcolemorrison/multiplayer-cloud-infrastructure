# Instance template that defines the properties for each instance in the instance group
resource "google_compute_instance_template" "server" {
  count        = length(var.deployment_regions)
  name_prefix  = "instance-template-${var.deployment_regions[count.index]}"
  machine_type = "n1-standard-1"

  disk {
    source_image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2004-lts"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    subnetwork = element(google_compute_subnetwork.subnet.*.self_link, count.index)
  }

  metadata = {
    project_name = var.project_name
  }

  metadata_startup_script = templatefile("${path.module}/scripts/server.sh", {
    REDIS_HOST = google_redis_instance.cache[count.index].host
    NODE_ENV = var.environment_type
    PORT = var.server_port
    APP_VERSION = var.app_version
  })

  tags = ["server"]

  lifecycle {
    create_before_destroy = true
  }
}

# Instance group manager that manages instances based on the instance template
resource "google_compute_region_instance_group_manager" "server" {
  count              = length(var.deployment_regions)
  name               = "instance-group-manager-${var.deployment_regions[count.index]}"
  base_instance_name = "${var.project_name}-instance-${var.deployment_regions[count.index]}"
  region             = var.deployment_regions[count.index]

  version {
    instance_template = element(google_compute_instance_template.server.*.self_link, count.index)
  }

  target_size = 2

  named_port {
    name = "http"
    port = var.server_port
  }

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 2
    max_unavailable_fixed = 1
  }
}

# Backend service that routes incoming traffic to the appropriate instance group
resource "google_compute_backend_service" "server" {
  name                  = "${var.project_name}-server-backend"
  protocol              = "HTTP"
  timeout_sec           = 10
  enable_cdn            = false
  load_balancing_scheme = "EXTERNAL_MANAGED"
  session_affinity      = "CLIENT_IP"

  dynamic "backend" {
    for_each = google_compute_region_instance_group_manager.server
    content {
      group           = backend.value.instance_group
      balancing_mode  = "UTILIZATION"
      max_utilization = 0.8
      capacity_scaler = 1
    }
  }

  health_checks = [google_compute_health_check.server.self_link]
}

# Health check that checks the health of the instances in the instance group
resource "google_compute_health_check" "server" {
  name               = "${var.project_name}-server"
  check_interval_sec = 1
  timeout_sec        = 1
  http_health_check {
    port         = "${var.server_port}"
    request_path = "/health"
  }
}

# URL map that maps URLs to backend services
resource "google_compute_url_map" "server" {
  name            = "${var.project_name}-server-url-map"
  default_service = google_compute_backend_service.server.self_link
}

# HTTP proxy that uses the URL map to route incoming requests
resource "google_compute_target_http_proxy" "server" {
  name    = "${var.project_name}-server-http-proxy"
  url_map = google_compute_url_map.server.self_link
}

resource "google_compute_global_address" "server" {
  name = "server-static-ip"
}

# Global forwarding rule that forwards incoming traffic to the HTTP proxy
resource "google_compute_global_forwarding_rule" "server" {
  name                  = "${var.project_name}-server-forwarding-rule"
  target                = google_compute_target_http_proxy.server.self_link
  ip_address            = google_compute_global_address.server.address
  port_range            = "${var.server_port}"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}