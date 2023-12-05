variable "region" {
  description = "The region to use"
  default     = "europe-west4"
  type        = string
}

variable "function_region" {
  description = "The region to use for deploying the Cloud Function"
  default     = "europe-west1"
  type        = string
}

variable "tfstate_bucket_location" {
  description = "The location for the GCS bucket for the terraform state"
  default     = "EU"
  type        = string
}

variable "zone_suffix" {
  description = "The suffix of zone in var.region to use (without the '-')"
  default     = "a"
  type        = string
}

variable "project_id" {
  description = "The ID of the project to use"
  type        = string
}

variable "services_to_enable" {
  description = "the services to enable"
  type        = set(string)
  default = [
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "osconfig.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com",
    "sourcerepo.googleapis.com",
  ]
}

variable "iac_roles" {
  description = "Roles needed to deploy the IAC Infra"
  type        = set(string)
  default = [
    "roles/owner",
    "roles/editor",
    "roles/logging.logWriter",
    "roles/resourcemanager.projectIamAdmin"
  ]
}
