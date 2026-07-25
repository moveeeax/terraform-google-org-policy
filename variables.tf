variable "project_id" {
  description = "ID of the project the organization policy is applied to."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "constraint" {
  description = <<-EOT
    Constraint the policy enforces, either bare ("compute.requireOsLogin") or
    fully qualified ("constraints/compute.requireOsLogin"); the prefix is
    stripped before the policy name is built. Must be "<service>.<name>", the
    form the Organization Policy API matches against — an unrecognised name is
    accepted on create and then never applies to anything.
  EOT
  type        = string

  validation {
    condition     = can(regex("^(constraints/)?[a-zA-Z][a-zA-Z0-9_-]*\\.[a-zA-Z][a-zA-Z0-9_.-]*$", var.constraint))
    error_message = "constraint must look like \"<service>.<constraintName>\" (optionally prefixed with \"constraints/\"), e.g. \"compute.requireOsLogin\" or \"custom.myConstraint\"."
  }
}

variable "boolean_enforced" {
  description = "For boolean constraints, whether the constraint is enforced. Defaults to true; setting it to false applies a policy that explicitly permits the behaviour the constraint guards."
  type        = bool
  default     = true
}

variable "inherit_from_parent" {
  description = <<-EOT
    For list constraints, whether rules set higher in the resource hierarchy are
    inherited and merged into the effective policy. Left unset (null) by default,
    which the API treats as false: this policy becomes the new root of evaluation
    and silently replaces a stricter policy inherited from the folder or the
    organization. Must stay null for boolean constraints, which reject the field.
  EOT
  type        = bool
  default     = null
}

variable "rules" {
  description = <<-EOT
    Optional list of policy rules. When set, overrides the simple boolean rule.
    Each rule must set exactly one of enforce, allow_all, deny_all, or values
    (allowed_values / denied_values) — the API models these as a union field, so
    a rule setting none of them, or more than one, is not a valid policy rule.
  EOT
  type = list(object({
    enforce        = optional(bool)
    allow_all      = optional(bool)
    deny_all       = optional(bool)
    allowed_values = optional(list(string))
    denied_values  = optional(list(string))
  }))
  default = null

  validation {
    condition     = var.rules == null || length(coalesce(var.rules, [])) > 0
    error_message = "rules must not be an empty list: that applies a policy with no rules at all, which enforces nothing. Leave it null to fall back to boolean_enforced."
  }

  validation {
    condition = var.rules == null || alltrue([
      for rule in coalesce(var.rules, []) : length([
        for kind in [
          rule.enforce != null,
          rule.allow_all != null,
          rule.deny_all != null,
          rule.allowed_values != null || rule.denied_values != null,
        ] : kind if kind
      ]) == 1
    ])
    error_message = "Each rule must set exactly one of enforce, allow_all, deny_all, or values (allowed_values / denied_values)."
  }

  validation {
    condition = var.rules == null || alltrue([
      for rule in coalesce(var.rules, []) :
      (rule.allow_all == null || rule.allow_all) && (rule.deny_all == null || rule.deny_all)
    ])
    error_message = "allow_all and deny_all may only be set to true; the API only recognises \"TRUE\", so a false value produces a rule that applies cleanly and does nothing. Omit the attribute instead."
  }
}
