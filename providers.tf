terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.17.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.default_region
}

data "google_compute_zones" "available" {
  count  = length(var.deployment_regions)
  region = var.deployment_regions[count.index]
}