# Agent instructions

This is a specification repository, not an application repository.

- Keep changes in requirements, principles, test scenarios, traceability, or
  agent guidance; do not add runtime implementation.
- Ground claims in the attached SonarCloud exporter and identify proposals or
  unresolved concerns as such rather than presenting them as existing behavior.
- Keep each normative requirement testable and give it a stable `REQ-*` ID.
- Keep acceptance scenarios technology-neutral and link each scenario to its
  requirement IDs.
- Preserve secret and data boundaries: never copy credential values, keychain
  manifests, exported Sonar data, tokens, or private organization/project data
  into this repository.
- Reuse the stated dependency contracts instead of specifying duplicate
  transport or keychain layers.
- When changing behavior specifications, update the matching acceptance
  scenario and the observed-baseline note if the source implementation changes.
