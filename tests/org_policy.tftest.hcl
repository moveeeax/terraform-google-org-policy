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

# --- parent -------------------------------------------------------------------

run "folder_parent_builds_the_folder_policy_name" {
  variables {
    project_id = null
    parent     = "folders/123456789012"
  }

  assert {
    condition     = google_org_policy_policy.this.name == "folders/123456789012/policies/compute.requireOsLogin"
    error_message = "Policy name must be folders/<id>/policies/<constraint> when parent is a folder."
  }

  assert {
    condition     = google_org_policy_policy.this.parent == "folders/123456789012"
    error_message = "Parent must be passed through unchanged."
  }
}

run "organization_parent_builds_the_organization_policy_name" {
  variables {
    project_id = null
    parent     = "organizations/456"
    constraint = "constraints/gcp.resourceLocations"
    rules      = [{ allowed_values = ["in:eu-locations"] }]
  }

  assert {
    condition     = google_org_policy_policy.this.name == "organizations/456/policies/gcp.resourceLocations"
    error_message = "Policy name must be organizations/<id>/policies/<constraint> when parent is an organization."
  }

  assert {
    condition     = google_org_policy_policy.this.parent == "organizations/456"
    error_message = "Parent must be passed through unchanged."
  }
}

run "project_parent_matches_project_id_shorthand" {
  variables {
    project_id = null
    parent     = "projects/example-project"
  }

  assert {
    condition     = google_org_policy_policy.this.name == "projects/example-project/policies/compute.requireOsLogin"
    error_message = "parent = \"projects/x\" must build the same name as project_id = \"x\", otherwise switching between them replaces the policy."
  }
}

run "rejects_both_project_id_and_parent" {
  command = plan

  variables {
    parent = "folders/123456789012"
  }

  expect_failures = [google_org_policy_policy.this]
}

run "rejects_neither_project_id_nor_parent" {
  command = plan

  variables {
    project_id = null
  }

  expect_failures = [google_org_policy_policy.this]
}

run "rejects_parent_with_an_unknown_kind" {
  command = plan

  variables {
    project_id = null
    parent     = "billingAccounts/0123AB"
  }

  expect_failures = [var.parent]
}

run "rejects_folder_parent_given_by_name" {
  command = plan

  variables {
    project_id = null
    parent     = "folders/engineering"
  }

  expect_failures = [var.parent]
}

run "rejects_bare_parent_id" {
  command = plan

  variables {
    project_id = null
    parent     = "123456789012"
  }

  expect_failures = [var.parent]
}

# --- dry run ------------------------------------------------------------------

run "dry_run_spec_is_absent_by_default" {
  assert {
    condition     = length(google_org_policy_policy.this.dry_run_spec) == 0
    error_message = "No dry_run_spec must be emitted unless dry_run is set."
  }

  assert {
    condition     = length(google_org_policy_policy.this.spec) == 1
    error_message = "The live spec must be emitted by default."
  }
}

run "dry_run_spec_is_emitted_alongside_the_live_spec" {
  variables {
    constraint = "gcp.resourceLocations"
    rules      = [{ allowed_values = ["in:us-locations"] }]
    dry_run = {
      rules               = [{ allowed_values = ["in:eu-locations"] }]
      inherit_from_parent = true
    }
  }

  assert {
    condition     = google_org_policy_policy.this.dry_run_spec[0].rules[0].values[0].allowed_values == tolist(["in:eu-locations"])
    error_message = "dry_run rules must reach dry_run_spec."
  }

  assert {
    condition     = google_org_policy_policy.this.dry_run_spec[0].inherit_from_parent == true
    error_message = "dry_run.inherit_from_parent must reach dry_run_spec."
  }

  assert {
    condition     = google_org_policy_policy.this.spec[0].rules[0].values[0].allowed_values == tolist(["in:us-locations"])
    error_message = "The live spec must keep its own rules when dry_run is set."
  }
}

run "boolean_dry_run_rule_maps_enforce" {
  variables {
    dry_run = { rules = [{ enforce = true }] }
  }

  assert {
    condition     = google_org_policy_policy.this.dry_run_spec[0].rules[0].enforce == "TRUE"
    error_message = "A dry-run enforce = true rule must map to \"TRUE\"."
  }

  assert {
    condition     = google_org_policy_policy.this.dry_run_spec[0].inherit_from_parent == null
    error_message = "dry_run.inherit_from_parent must stay unset unless asked for; boolean constraints reject the field."
  }
}

run "enforce_false_ships_dry_run_only" {
  variables {
    enforce = false
    dry_run = { rules = [{ enforce = true }] }
  }

  assert {
    condition     = length(google_org_policy_policy.this.spec) == 0
    error_message = "enforce = false must drop the live spec."
  }

  assert {
    condition     = length(google_org_policy_policy.this.dry_run_spec) == 1
    error_message = "enforce = false must still ship the dry-run spec."
  }
}

run "rejects_enforce_false_without_dry_run" {
  command = plan

  variables {
    enforce = false
  }

  expect_failures = [google_org_policy_policy.this]
}

run "rejects_dry_run_with_empty_rules" {
  command = plan

  variables {
    dry_run = { rules = [] }
  }

  expect_failures = [var.dry_run]
}

run "rejects_dry_run_rule_mixing_kinds" {
  command = plan

  variables {
    dry_run = {
      rules = [{
        enforce        = true
        allowed_values = ["projects/example-project"]
      }]
    }
  }

  expect_failures = [var.dry_run]
}

run "rejects_dry_run_deny_all_false" {
  command = plan

  variables {
    dry_run = { rules = [{ deny_all = false }] }
  }

  expect_failures = [var.dry_run]
}
