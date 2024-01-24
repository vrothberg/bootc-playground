variable "project" {
  type = string
  description = "Your GCP project ID"
}

variable "region" {
  type = string
  description = "GCP region"
  default = "us-central1"
}

variable "region_zone" {
  type = string
  description = "GCP region and zone"
  default = "us-central1-f"
}

# This is the new important variable!  It will be injected into the startup
# script; see `provision.tf`.
variable "bootc_image" {
  type = string
  description = "Your bootable container"
}
