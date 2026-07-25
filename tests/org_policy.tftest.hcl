# Runs with a mocked provider: no credentials, no network, no GCP project.
# `mock_provider` requires Terraform >= 1.7 (or OpenTofu >= 1.7) to *run* these
# tests; the module itself deliberately still declares required_version >= 1.5
# so consumers are not forced to upgrade.
mock_provider "google" {}

variables {
  project_id = "example-project"
  constraint = "compute.requireOsLogin"
}

run "boolean_constraint_is_enforced_by_default" {
  assert {
    condition     = google_org_policy_policy.this.spec[0].rules[0].enforce == "TRUE"
    error_message = "A boolean constraint must default to enforced; a policy that ships not enforcing is decorative."
  }

  assert {
    condition     = google_org_policy_policy.this.spec[0].rules[0].allow_all == null && google_org_policy_policy.this.spec[0].rules[0].deny_all == null
    error_message = "The boolean fallback rule must set only enforce."
  }

  assert {
    condition     = length(google_org_policy_policy.this.spec[0].rules[0].values) == 0
    error_message = "The boolean fallback rule must not emit a values block."
  }
}

run "boolean_enforced_false_is_not_inverted" {
  variables {
    boolean_enforced = false
  }

  assert {
    condition     = google_org_policy_policy.this.spec[0].rules[0].enforce == "FALSE"
    error_message = "boolean_enforced = false must map to \"FALSE\", not the inverse."
  }
}

run "policy_name_uses_the_bare_constraint_name" {
  assert {
    condition     = google_org_policy_policy.this.name == "projects/example-project/policies/compute.requireOsLogin"
    error_message = "Policy name must be projects/<id>/policies/<constraint>."
  }

  assert {
    condition     = google_org_policy_policy.this.parent == "projects/example-project"
    error_message = "Parent must be the project the policy is attached to."
  }
}

run "fully_qualified_constraint_is_normalised" {
  variables {
    constraint = "constraints/compute.requireOsLogin"
  }

  assert {
    condition     = google_org_policy_policy.this.name == "projects/example-project/policies/compute.requireOsLogin"
    error_message = "A \"constraints/\"-prefixed name must be stripped, otherwise the policy name matches no constraint."
  }
}

run "rejects_constraint_without_a_service_prefix" {
  command = plan

  variables {
    constraint = "requireOsLogin"
  }

  expect_failures = [var.constraint]
}

run "rejects_constraint_with_a_path_separator" {
  command = plan

  variables {
    constraint = "constraints/compute/requireOsLogin"
  }

  expect_failures = [var.constraint]
}

run "rejects_empty_constraint" {
  command = plan

  variables {
    constraint = ""
  }

  expect_failures = [var.constraint]
}

run "rejects_empty_project_id" {
  command = plan

  variables {
    project_id = "  "
  }

  expect_failures = [var.project_id]
}

# --- list constraints ---------------------------------------------------------

run "denied_values_rule_is_emitted" {
  variables {
    constraint = "compute.vmExternalIpAccess"
    rules = [{
      denied_values = ["projects/example-project/zones/us-central1-a/instances/public-vm"]
    }]
  }

  assert {
    condition     = google_org_policy_policy.this.spec[0].rules[0].values[0].denied_values == tolist(["projects/example-project/zones/us-central1-a/instances/public-vm"])
    error_message = "denied_values must be passed through to the values block."
  }

  assert {
    condition     = google_org_policy_policy.this.spec[0].rules[0].enforce == null
    error_message = "A list rule must not also carry enforce."
  }
}

run "allow_all_rule_is_emitted" {
  variables {
    constraint = "gcp.resourceLocations"
    rules      = [{ allow_all = true }]
  }

  assert {
    condition     = google_org_policy_policy.this.spec[0].rules[0].allow_all == "TRUE"
    error_message = "allow_all = true must map to \"TRUE\"."
  }
}

run "inherit_from_parent_is_unset_by_default" {
  assert {
    condition     = google_org_policy_policy.this.spec[0].inherit_from_parent == null
    error_message = "inherit_from_parent must stay unset unless asked for; boolean constraints reject the field."
  }
}

run "inherit_from_parent_is_passed_through" {
  variables {
    constraint          = "gcp.resourceLocations"
    inherit_from_parent = true
    rules               = [{ denied_values = ["in:us-west1-locations"] }]
  }

  assert {
    condition     = google_org_policy_policy.this.spec[0].inherit_from_parent == true
    error_message = "inherit_from_parent = true must reach the spec, otherwise a project policy silently replaces a stricter inherited one."
  }
}

# --- rule shape ---------------------------------------------------------------

run "rejects_empty_rules_list" {
  command = plan

  variables {
    rules = []
  }

  expect_failures = [var.rules]
}

run "rejects_rule_setting_no_kind" {
  command = plan

  variables {
    rules = [{}]
  }

  expect_failures = [var.rules]
}

run "rejects_rule_mixing_enforce_and_values" {
  command = plan

  variables {
    rules = [{
      enforce        = true
      allowed_values = ["projects/example-project"]
    }]
  }

  expect_failures = [var.rules]
}

run "rejects_rule_mixing_allow_all_and_deny_all" {
  command = plan

  variables {
    rules = [{
      allow_all = true
      deny_all  = true
    }]
  }

  expect_failures = [var.rules]
}

run "rejects_deny_all_false" {
  command = plan

  variables {
    rules = [{ deny_all = false }]
  }

  expect_failures = [var.rules]
}

run "rejects_allow_all_false" {
  command = plan

  variables {
    rules = [{ allow_all = false }]
  }

  expect_failures = [var.rules]
}
