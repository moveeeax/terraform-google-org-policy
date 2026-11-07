locals {
  # The API expects the bare constraint name inside the resource name
  # ("projects/<id>/policies/compute.requireOsLogin"), not the fully qualified
  # "constraints/..." form. Accept either and normalise: a name the API does not
  # recognise is still accepted on create and simply never matches a constraint.
  constraint = replace(var.constraint, "/^constraints\\//", "")

  # project_id is shorthand for parent = "projects/<id>". Exactly one of the two
  # is set; the precondition on the resource reports the error, this only keeps
  # the expression from failing first when neither is.
  parent = var.parent != null ? var.parent : (var.project_id != null ? "projects/${var.project_id}" : null)

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

  # Same normalisation for the dry-run rules. dry_run has no boolean fallback:
  # its rules are always given explicitly.
  dry_run_rules = var.dry_run == null ? [] : [
    for rule in var.dry_run.rules : {
      enforce        = rule.enforce
      allow_all      = rule.allow_all
      deny_all       = rule.deny_all
      allowed_values = rule.allowed_values
      denied_values  = rule.denied_values
    }
  ]
}

resource "google_org_policy_policy" "this" {
  name   = "${local.parent}/policies/${local.constraint}"
  parent = local.parent

  # The live policy. enforce = false drops it so only the dry-run spec ships:
  # violations are then reported in audit logs but nothing is blocked.
  dynamic "spec" {
    for_each = var.enforce ? [1] : []
    content {
      # Unset by default. For list constraints an unset (false) value makes this
      # policy the new root of evaluation, so it silently replaces a stricter
      # policy inherited from the folder or organization; set it to true to
      # merge with the parent instead. Boolean constraints must leave it unset.
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

  dynamic "dry_run_spec" {
    for_each = var.dry_run == null ? [] : [var.dry_run]
    content {
      inherit_from_parent = dry_run_spec.value.inherit_from_parent

      dynamic "rules" {
        for_each = local.dry_run_rules
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

  lifecycle {
    precondition {
      condition     = (var.project_id == null) != (var.parent == null)
      error_message = "Set exactly one of project_id or parent: project_id = \"x\" is shorthand for parent = \"projects/x\"."
    }

    precondition {
      condition     = var.enforce || var.dry_run != null
      error_message = "enforce = false needs dry_run: without either spec the policy carries no rules at all."
    }
  }
}
