# Create a Redis instance in each region
resource "google_redis_instance" "cache" {
  count              = length(var.deployment_regions)
  name               = format("redis-%s-%d", var.deployment_regions[count.index], count.index + 1)
  memory_size_gb     = 1
  region             = var.deployment_regions[count.index]
  authorized_network = google_compute_network.vpc_network.self_link
  redis_version      = "REDIS_7_2"
  display_name       = format("Redis Instance %s %d", var.deployment_regions[count.index], count.index + 1)
}