# terraform-google-org-policy

Terraform module that manages a [Google Cloud](https://cloud.google.com/)
organization policy (`google_org_policy_policy`) at the project level. It
supports simple boolean constraints and, for list constraints, allow/deny
value rules.

## Usage

### Boolean constraint

```hcl
module "os_login" {
  source = "github.com/moveeeax/terraform-google-org-policy"

  project_id       = var.project_id
  constraint       = "compute.requireOsLogin"
  boolean_enforced = true
}
```

`constraint` may be given bare (`compute.requireOsLogin`) or fully qualified
(`constraints/compute.requireOsLogin`) — the prefix is stripped before the
policy name is built, because the API expects the bare form in
`projects/<id>/policies/<constraint>`.

### List constraint

```hcl
module "resource_locations" {
  source = "github.com/moveeeax/terraform-google-org-policy"

  project_id = var.project_id
  constraint = "gcp.resourceLocations"

  # Merge with the org/folder policy instead of replacing it. See below.
  inherit_from_parent = true

  rules = [{
    allowed_values = ["in:eu-locations"]
  }]
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Semantics you need to get right

**Boolean constraints.** `boolean_enforced` defaults to `true`, which renders
`enforce = "TRUE"`. Setting it to `false` does not "skip" the policy — it
applies a policy that explicitly *permits* the behaviour the constraint guards,
overriding a parent policy that enforced it.

**Rule kinds are mutually exclusive.** In the API, `enforce`, `allow_all`,
`deny_all` and `values` are a union field: a rule sets exactly one of them.
The module validates this, so a rule that sets none (`{}`) or several
(`{ enforce = true, allowed_values = [...] }`) is rejected at plan time rather
than being sent to the API. `enforce` is only valid for boolean constraints;
`allow_all`, `deny_all` and `values` only for list constraints.

`allow_all` and `deny_all` accept `true` only. The API recognises `"TRUE"`;
a `false` value renders a rule that applies cleanly and enforces nothing, so
the module rejects it — omit the attribute instead. Likewise `rules = []` is
rejected: it would create a policy with no rules, which enforces nothing.
Leave `rules` unset (`null`) to fall back to the boolean rule.

**`inherit_from_parent` and stricter parents.** For list constraints this
controls whether rules set higher in the resource hierarchy are merged into the
effective policy. It is unset by default, which the API treats as `false`:
**this project policy becomes the new root of evaluation and silently replaces a
stricter policy inherited from the folder or organization.** Set it to `true`
whenever the project policy is meant to narrow an inherited one rather than
supersede it. Boolean constraints reject the field, so it must stay `null` for
them.

**Constraint names are not checked by the API.** A misspelled constraint is
accepted on create and then simply never matches anything, so the policy looks
applied and enforces nothing. The module validates the `<service>.<name>` shape,
which catches structural mistakes (`requireOsLogin`,
`constraints/compute/requireOsLogin`); it cannot catch a typo inside an
otherwise well-formed name, so check the value against the
[constraint reference](https://cloud.google.com/resource-manager/docs/organization-policy/org-policy-constraints).

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| google    | >= 5.0   |

Running the test suite (`terraform test`) additionally needs Terraform >= 1.7
or OpenTofu >= 1.7 for `mock_provider`. That is a requirement of the tests only;
consuming the module still needs no more than 1.5.

## Inputs

| Name                  | Description                                                                    | Type           | Default | Required |
|-----------------------|--------------------------------------------------------------------------------|----------------|---------|:--------:|
| `project_id`          | ID of the project the policy is applied to.                                    | `string`       | n/a     |   yes    |
| `constraint`          | Constraint the policy enforces, with or without the `constraints/` prefix.     | `string`       | n/a     |   yes    |
| `boolean_enforced`    | For boolean constraints, whether the constraint is enforced.                   | `bool`         | `true`  |    no    |
| `inherit_from_parent` | For list constraints, merge with policies inherited from the parent.           | `bool`         | `null`  |    no    |
| `rules`               | Optional list of policy rules overriding the boolean rule.                     | `list(object)` | `null`  |    no    |

`rules` element shape:

| Attribute        | Type           | Notes                                              |
|------------------|----------------|----------------------------------------------------|
| `enforce`        | `bool`         | Boolean constraints only.                          |
| `allow_all`      | `bool`         | List constraints only; `true` is the only value.   |
| `deny_all`       | `bool`         | List constraints only; `true` is the only value.   |
| `allowed_values` | `list(string)` | List constraints only.                             |
| `denied_values`  | `list(string)` | List constraints only.                             |

## Outputs

| Name   | Description                                    |
|--------|------------------------------------------------|
| `id`   | Identifier of the organization policy.        |
| `name` | Resource name of the organization policy.     |

## Testing

```sh
terraform init -backend=false
terraform test
```

The suite uses a mocked provider, so it needs no credentials and no network.

## License

[MIT](LICENSE)
