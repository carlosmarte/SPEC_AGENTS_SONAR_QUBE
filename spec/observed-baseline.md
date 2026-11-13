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

## Follow-up verification gaps

- The checked-in test scenarios do not assert all output-tree paths or every
  listed resource endpoint independently.
- `safe()`'s observed replacement of unsafe characters should be tested against
  path traversal and collisions if the path contract is expanded.
- The local source repository tracks a `.env.keychain` file, but its contents
  were intentionally not read or copied. A future source change should verify
  that any tracked manifest contains references only and is trusted according
  to the keychain package contract.
