variable "project_id" {
  description = "ID of the project the organization policy is applied to."
  type        = string
}

variable "constraint" {
  description = "Constraint the policy enforces, e.g. constraints/compute.requireOsLogin."
  type        = string
}

variable "boolean_enforced" {
  description = "For boolean constraints, whether the constraint is enforced."
  type        = bool
  default     = true
}

variable "rules" {
  description = "Optional list of policy rules. When set, overrides the simple boolean rule."
  type = list(object({
    enforce        = optional(bool)
    allow_all      = optional(bool)
    deny_all       = optional(bool)
    allowed_values = optional(list(string))
    denied_values  = optional(list(string))
  }))
  default = null
}
