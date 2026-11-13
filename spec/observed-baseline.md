# Observed baseline and open concerns

This document separates behavior observed in the attached source project from
the normative requirements in `requirements.md`. Observations are based on its
README, package metadata, exporter source, tests, and its tracked concern note.
No credential file, credential value, or exported data was copied.

## Observed behavior

- The project is a Node.js ES module with a minimum Node version of 20.19.
- The default endpoint is `https://sonarcloud.io`; output defaults to `data/`
  and project concurrency defaults to three.
- `SONAR_TOKEN` is resolved through a keychain-env package; the entrypoint
  rejects startup when the token is not available.
- The exporter uses an HTTP fetch package with bearer auth, finite timeouts, retries,
  jitter, and Retry-After support. The client is closed in a `finally` block.
- Pagination handles both Sonar paging metadata styles, stops on empty pages,
  and marks results truncated at the 10,000-result ceiling.
- Project metric keys are requested in groups of 50. Project exports use a
  concurrency-limited worker pool.
- Resource retrieval failures are accumulated in the manifest. 401, 403, and
  404 are quiet; other failures are warned about.
- Unit tests cover helpers, pagination, status classification, file writing,
  metric batching, authentication rejection, and manifest generation.
- Mock-server integration tests cover authenticated requests, paging, rate
  limit retry, partial failures, and bad-token behavior. The live test is
  opt-in.

## Observed deviations from requirements

A source review on 2026-11-13 found these differences between the source
implementation and the requirements. They describe current source behavior;
the requirements state the intended behavior. The keychain row was confirmed
by running the source entry point; the other rows come from reading the source
and from new tests that fail against it.

| Requirement | Observed source behavior |
| --- | --- |
| REQ-PAGE-005 | Measure history is paged as if each per-metric entry were one result. A project with more history points than metrics keeps requesting pages until the result cap, saves each metric several times with its history split across copies, and marks the resource truncated. |
| REQ-CONFIG-007 | `SONAR_CONCURRENCY` is converted with `Number()`. An empty or non-numeric value becomes `0` or `NaN`, no project workers start, and the run reports success with no project data. |
| REQ-OUTPUT-002 | Sanitization keeps dots, so a key of `..` or `.` is used as a path segment unchanged. Different keys such as `a/b` and `a:b` map to the same segment and overwrite each other. |
| REQ-OUTPUT-005 | The output directory is never cleared. Files from earlier runs stay next to a manifest that records the same resource as failed, and deleted projects remain. |
| REQ-OUTPUT-004 | `manifest.json` is written before it is counted, so the on-disk file count is one lower than the count returned to the caller. |
| REQ-ERROR-003 | When metric definitions cannot be fetched, every project's measures are saved as an empty list. |
| REQ-ERROR-005 | A failed organization search is recorded as a resource error, and the run finishes successfully with zero organizations. |
| REQ-ERROR-006 | The process exits with status 0 even when unexpected resource failures were recorded. |
| REQ-PAGE-006 | Project tags are requested once with a limit of 100 and are never marked truncated. |
| REQ-SEC-005 | Error records include up to 300 characters of the raw response body and the request parameters. |
| REQ-OUTPUT-006 | Output is written with the process's default file permissions. |
| REQ-CONFIG-004, REQ-SEC-002 | The entry point resolves the keychain manifest even when `SONAR_TOKEN` is already set. With an unapproved manifest, as on a CI machine, the run fails before it uses the supplied token or validates its configuration. |

## Source repository concerns

These are not new requirements and are not represented as solved:

1. The source concern note reports that a clean clone may not install because
   dependencies point to ignored `vendors/` directories and the HTTP fetch
   package needs to be built. Dependency bootstrap/reproducibility
   remains an open implementation concern.
2. The source README contains only a heading. Usage, credential setup,
   configuration, tests, and output documentation remain missing there.
3. The source concern note reports that the associated SonarCloud project has
   no analysis data; an empty export in that state is not evidence of exporter
   failure.
4. SonarCloud's 10,000-result ceiling may omit data. The current behavior marks
   truncation; full extraction would require a separately specified slicing
   strategy.
5. The source concern note reports noisy client warnings at the default log
   level; the source scripts reduce noise by setting log levels.
6. The source declares a minimum Node version of 20.19, but its test scripts
   pass quoted glob patterns to the built-in test runner, which expands them
   only from Node 21. On Node 20 the test scripts find no test files. The
   minimum version and the test scripts need to agree; Node 20 reached end of
   life in April 2026.

## Follow-up verification gaps

- The checked-in test scenarios do not assert all output-tree paths or every
  listed resource endpoint independently.
- The path contract is now expanded (REQ-OUTPUT-002). The source test for
  identifier sanitization covers `../../etc` but not `..`, `.`, or colliding
  keys.
- Configuration is read when the source entry point loads, so the
  configuration scenarios (REQ-CONFIG-001 to REQ-CONFIG-003 and
  REQ-CONFIG-007) cannot be run against the source without starting a
  process. Client cleanup after a run-level failure (REQ-CONFIG-006) is also
  untested.
- No source test checks that the token is absent from logs, error records,
  and the manifest (REQ-SEC-001, REQ-SEC-005), or that project concurrency
  stays bounded during a full export rather than only in the worker-pool
  helper (REQ-EXPORT-004).
- The local source repository tracks a `.env.keychain` file, but its contents
  were intentionally not read or copied. A future source change should verify
  that any tracked manifest contains references only and is trusted according
  to the keychain package contract.
