---
name: sonarqube-export-spec
description: Maintain behavioral requirements and acceptance scenarios for the SonarCloud exporter without adding implementation code.
---

# SonarCloud exporter specification skill

Use this skill when deriving, reviewing, or updating the exporter requirements,
acceptance scenarios, or agent guidance.

## Workflow

1. Read `spec/requirements.md`, `spec/acceptance.feature`, and
   `spec/observed-baseline.md` before proposing edits.
2. Inspect only the relevant source behavior and tests. Treat source data,
   credentials, and generated exports as sensitive; do not copy any of them
   into this repository.
3. Separate observed behavior, normative requirements, and unresolved
   proposals. Do not silently convert a source defect or concern into an
   intended requirement.
4. Give each new normative requirement a stable `REQ-*` identifier and add or
   update at least one Gherkin scenario that verifies its externally
   observable behavior.
5. Prefer fake-server and temporary-directory acceptance tests. Keep live
   SonarCloud tests opt-in and never require a real token for ordinary
   verification.
6. Reuse the generic package responsibilities documented in requirements
   for HTTP fetch and `keychain-env`; do not duplicate or re-specify their
   internal mechanisms.
7. Check that the update introduces no runtime implementation, secret,
   `.env.keychain` file, token, exported data, or private organization/project
   detail.

## Specification principles

- Specify behavior and invariants, not source-level structure.
- Make failure modes, permissions, result limits, concurrency, and cleanup
  explicit.
- Distinguish partial resource failure from authentication/run-level failure.
- Preserve privacy-by-default: output is local and sensitive; secrets are
  never emitted.
- Keep requirements testable and acceptance scenarios traceable to them.
