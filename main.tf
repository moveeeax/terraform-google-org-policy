locals {
  boolean_fallback = [
    {
      enforce        = var.boolean_enforced
      allow_all      = null
      deny_all       = null
      allowed_values = null
      denied_values  = null
    }
  ]

  # Normalise every rule to the same fully-shaped object so the dynamic block
  # can reference all attributes regardless of which were supplied.
  effective_rules = var.rules == null ? local.boolean_fallback : [
    for rule in var.rules : {
      enforce        = try(rule.enforce, null)
      allow_all      = try(rule.allow_all, null)
      deny_all       = try(rule.deny_all, null)
      allowed_values = try(rule.allowed_values, null)
      denied_values  = try(rule.denied_values, null)
    }
  ]
}

resource "google_org_policy_policy" "this" {
  name   = "projects/${var.project_id}/policies/${var.constraint}"
  parent = "projects/${var.project_id}"

  spec {
    dynamic "rules" {
      for_each = local.effective_rules
      content {
        enforce   = rules.value.enforce == null ? null : (rules.value.enforce ? "TRUE" : "FALSE")
        allow_all = rules.value.allow_all == null ? null : (rules.value.allow_all ? "TRUE" : "FALSE")
        deny_all  = rules.value.deny_all == null ? null : (rules.value.deny_all ? "TRUE" : "FALSE")

        dynamic "values" {
          for_each = (rules.value.allowed_values != null || rules.value.denied_values != null) ? [1] : []
          content {
            allowed_values = rules.value.allowed_values
            denied_values  = rules.value.denied_values
          }
        }
      }
    }
  }
}
