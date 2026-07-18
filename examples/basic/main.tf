terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "org_policy" {
  source = "../.."

  project_id       = var.project_id
  constraint       = "compute.requireOsLogin"
  boolean_enforced = true
}

variable "project_id" {
  description = "Project ID the example policy is applied to."
  type        = string
}

variable "region" {
  description = "Region for the google provider."
  type        = string
  default     = "us-central1"
}

output "policy_name" {
  value = module.org_policy.name
}
