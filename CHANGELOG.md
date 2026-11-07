# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `parent` input to attach the policy to a folder (`folders/<id>`) or the
  organization (`organizations/<id>`) as well as a project. `project_id` stays
  as shorthand for `parent = "projects/<id>"` and is now optional; exactly one
  of the two must be set. Existing `project_id` callers plan no change.

### Changed

- CI: bump actions to their current majors, pin tool versions, and restrict the
  workflow token to `contents: read`.
- CI: add Dependabot for GitHub Actions and the Terraform provider.
- Docs: pin the README usage `source` to a release tag; fix the LICENSE year.

## [1.0.0]

Initial release (`v0.1.0` points at the same commit).

[Unreleased]: https://github.com/moveeeax/terraform-google-org-policy/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/moveeeax/terraform-google-org-policy/releases/tag/v1.0.0
