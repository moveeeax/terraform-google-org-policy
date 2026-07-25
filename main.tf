locals {
  # The API expects the bare constraint name inside the resource name
  # ("projects/<id>/policies/compute.requireOsLogin"), not the fully qualified
  # "constraints/..." form. Accept either and normalise: a name the API does not
  # recognise is still accepted on create and simply never matches a constraint.
  constraint = replace(var.constraint, "/^constraints\\//", "")

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
      enforce        = rule.enforce
      allow_all      = rule.allow_all
      deny_all       = rule.deny_all
      allowed_values = rule.allowed_values
      denied_values  = rule.denied_values
    }
  ]
}

resource "google_org_policy_policy" "this" {
  name   = "projects/${var.project_id}/policies/${local.constraint}"
  parent = "projects/${var.project_id}"

  spec {
    # Unset by default. For list constraints an unset (false) value makes this
    # policy the new root of evaluation, so it silently replaces a stricter
    # policy inherited from the folder or organization; set it to true to merge
    # with the parent instead. Boolean constraints must leave it unset.
    inherit_from_parent = var.inherit_from_parent

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
