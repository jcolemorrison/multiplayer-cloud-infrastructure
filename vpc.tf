# Create a VPC network
resource "google_compute_network" "vpc_network" {
  name                    = "${var.project_name}-vpc"
  auto_create_subnetworks = false
}

# Create subnets
resource "google_compute_subnetwork" "subnet" {
  count         = length(var.deployment_regions)
  name          = format("subnet-%s-%d", var.deployment_regions[count.index], count.index + 1)
  ip_cidr_range = cidrsubnet("10.0.0.0/16", 8, count.index)
  network       = google_compute_network.vpc_network.self_link
  region        = var.deployment_regions[count.index]
  private_ip_google_access = true
}

# Create a Cloud Router in each region
resource "google_compute_router" "router" {
  count   = length(var.deployment_regions)
  name    = format("%s-router-%d", var.project_name, count.index + 1)
  network = google_compute_network.vpc_network.self_link
  region  = var.deployment_regions[count.index]
}

# Create Cloud NAT in each region
resource "google_compute_router_nat" "cloud_nat" {
  count   = length(var.deployment_regions)
  name    = format("cloud-nat-%d", count.index + 1)
  router  = element(google_compute_router.router.*.name, count.index)
  region  = element(var.deployment_regions, count.index)
  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = element(google_compute_subnetwork.subnet.*.self_link, count.index)
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# Create a firewall rule that allows traffic on port 80
resource "google_compute_firewall" "server_firewall" {
  name    = "server-firewall"
  network = google_compute_network.vpc_network.self_link
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["0.0.0.0/0"]
}