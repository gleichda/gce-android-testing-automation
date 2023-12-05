variable "parallel_execution_count" {
  description = "The number of parallel test instances"
  default     = 100
  type        = number
}

variable "region" {
  description = "The region to use"
  default     = "europe-west4"
  type        = string
}

variable "zone_suffix" {
  description = "The suffix of zone in var.region to use (without the '-')"
  default     = "a"
  type        = string
}

variable "aos_machine_type" {
  description = "Machine type for aos instances"
  default     = "n2-highcpu-8"
  type        = string
}

variable "aos_image" {
  description = "The base image used for AOS instances"
  default     = "debian-cloud/debian-11"
  type        = string
}

variable "cts_machine_type" {
  description = "Machine type for the cts instance"
  default     = "n2-highcpu-32"
  type        = string
}

variable "cts_image" {
  description = "The base image used for AOS instances"
  default     = "debian-cloud/debian-11"
  type        = string
}

variable "project_id" {
  description = "The ID of the project to use"
  type        = string
}

variable "aos_port" {
  description = "The port that AOS device is using"
  type        = number
  default     = 6520
}

variable "image_path" {
  description = "the path in GCS where the android image lives"
  type        = string
}

