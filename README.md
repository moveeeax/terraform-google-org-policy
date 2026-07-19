# terraform-google-org-policy

Terraform module that manages a [Google Cloud](https://cloud.google.com/)
organization policy (`google_org_policy_policy`) at the project level. It
supports simple boolean constraints and, for list constraints, allow/deny
value rules.

## Usage

```hcl
module "org_policy" {
  source = "github.com/moveeeax/terraform-google-org-policy"

  project_id       = var.project_id
  constraint       = "compute.requireOsLogin"
  boolean_enforced = true
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| google    | >= 5.0   |

## Inputs

| Name               | Description                                              | Type           | Default | Required |
|--------------------|----------------------------------------------------------|----------------|---------|:--------:|
| `project_id`       | ID of the project the policy is applied to.              | `string`       | n/a     |   yes    |
| `constraint`       | Constraint the policy enforces.                          | `string`       | n/a     |   yes    |
| `boolean_enforced` | For boolean constraints, whether enforced.               | `bool`         | `true`  |    no    |
| `rules`            | Optional list of policy rules overriding the boolean.    | `list(object)` | `null`  |    no    |

## Outputs

| Name   | Description                                    |
|--------|------------------------------------------------|
| `id`   | Identifier of the organization policy.        |
| `name` | Resource name of the organization policy.     |

## License

[MIT](LICENSE)
