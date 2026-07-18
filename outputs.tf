output "id" {
  description = "Identifier of the organization policy."
  value       = google_org_policy_policy.this.id
}

output "name" {
  description = "Resource name of the organization policy."
  value       = google_org_policy_policy.this.name
}
