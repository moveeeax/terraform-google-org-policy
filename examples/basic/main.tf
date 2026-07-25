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

# Boolean constraint: enforced by default.
module "org_policy" {
  source = "../.."

  project_id       = var.project_id
  constraint       = "compute.requireOsLogin"
  boolean_enforced = true
}

# List constraint: narrows the allowed locations. inherit_from_parent keeps any
# stricter rule set on the folder or organization in the effective policy —
# without it this project policy would silently replace it.
module "resource_locations" {
  source = "../.."

  project_id          = var.project_id
  constraint          = "gcp.resourceLocations"
  inherit_from_parent = true

  rules = [{
    allowed_values = ["in:us-locations"]
  }]
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

output "resource_locations_policy_name" {
  value = module.resource_locations.name
}
