variable "gcp_project_id" {
  description = "The ID of the GCP project"
  type        = string
}

variable "project_name" {
  description = "default project name for grouping resources"
  type        = string
}

variable "default_region" {
  description = "default region for the project deployment"
  type        = string
  default     = "us-west1"
}

variable "deployment_regions" {
  description = "regions to deploy"
  type        = list(string)
  default     = ["us-central1", "us-west1", "us-east1"]
}

variable "server_port" {
  description = "The port the server will listen on"
  type        = number
  default     = 80
}

variable "environment_type" {
  description = "The environment type (e.g., 'development', 'staging', 'production')"
  type        = string
}

variable "app_version" {
  description = "The version of the application to be deployed (e.g., '1.0.0' sans the 'v')"
  type        = string
}

variable "server_cert_name" {
  description = "value of the server certificate name"
  type        = string
}

variable "client_site_service_account_email" {
  description = "The email of the service account"
  type        = string
}

variable "client_cert_name" {
  description = "value of the client certificate name"
  type        = string
}