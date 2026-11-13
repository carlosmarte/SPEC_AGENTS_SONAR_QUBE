# Behavioral requirements and design principles

## Purpose and scope

The system exports the SonarCloud resources accessible to the supplied
identity into a local, inspectable JSON snapshot. The specification covers the
observable contract, not implementation details. Resource availability depends
on the token's permissions and on the server's data.

“MUST” and “MUST NOT” are normative. “Should” indicates a recommended
operational property. Requirements are intended to be verified by the linked
acceptance scenarios.

## High-level primitives

1. **Credential resolution** — resolve `SONAR_TOKEN` from an already-provided
   environment value or from the approved macOS keychain manifest.
2. **Authenticated HTTP client** — issue API requests through `fetch-undici`
   with bearer authentication, explicit timeouts, retry policy, and lifecycle
   cleanup.
3. **Sonar API adapter** — map endpoint-relative requests to `/api/` paths,
   pass query parameters, parse JSON, and preserve HTTP status in failures.
4. **Paged collection** — support Sonar paging metadata in both
   `paging.total` and top-level `total` forms; stop on an empty page and report
   result-cap truncation.
5. **Resource traversal** — validate credentials, discover user-level data,
   enumerate member organizations, then enumerate projects and their supported
   project resources.
6. **Bounded project work** — export multiple projects without exceeding the
   configured concurrency limit.
7. **Snapshot writer** — write individual resources as pretty-printed JSON at
   deterministic, sanitized paths.
8. **Partial-failure ledger** — continue after individual resource failures,
   record failures in the manifest, and distinguish expected permission /
   unavailable responses from unexpected failures in diagnostics.
9. **Run manifest** — summarize the destination server, timing, organizations,
   project count, request/file counts, and skipped-resource errors.

## Functional requirements

### Configuration and startup

- **REQ-CONFIG-001** The default server URL MUST be `https://sonarcloud.io`;
  `SONAR_URL` may select another compatible Sonar server.
- **REQ-CONFIG-002** The output directory MUST be configurable with
  `SONAR_OUT`, defaulting to `data/`.
- **REQ-CONFIG-003** Project concurrency MUST be configurable with
  `SONAR_CONCURRENCY` and default to `3`.
- **REQ-CONFIG-004** A directly supplied `SONAR_TOKEN` environment variable
  MUST take precedence over keychain resolution.
- **REQ-CONFIG-005** Startup MUST fail clearly if no token is resolved and
  MUST validate the token with the authentication validation endpoint before
  writing export data.
- **REQ-CONFIG-006** The HTTP client MUST be closed on both successful and
  failed runs.

### API transport and pagination

- **REQ-HTTP-001** API requests MUST use bearer authentication and the
  `fetch-undici` client; the application-level adapter MUST address
  `/api/<endpoint>` and pass query parameters without silently changing them.
- **REQ-HTTP-002** Connect and read timeouts MUST be finite; retryable
  transient statuses MUST include 429, 500, 502, 503, and 504, with
  `Retry-After` honored where supported by the client.
- **REQ-PAGE-001** Collection retrieval MUST follow either
  `paging.total` or top-level `total` metadata.
- **REQ-PAGE-002** Pagination MUST terminate when a page is empty, even if
  metadata indicates more results.
- **REQ-PAGE-003** Search endpoints MUST NOT claim completeness beyond the
  SonarCloud 10,000-result limit. When the configured cap is reached while
  more results are indicated, saved collection data MUST be marked
  `truncated: true` and explain the cap.
- **REQ-PAGE-004** Metric keys used for project measure requests MUST be sent
  in batches no larger than 50, and their returned measures MUST be combined
  into one logical resource.
- **REQ-HTTP-003** An HTTP failure MUST retain its status code and endpoint
  context so downstream handling can classify it.

### Traversal and output

- **REQ-EXPORT-001** The export MUST validate authentication before requesting
  any resource data; invalid authentication MUST stop the run before output
  files are written.
- **REQ-EXPORT-002** The run MUST attempt user details, languages, metric
  definitions, organizations for which the user is a member, and organization
  data including projects, members, groups, quality gates/profiles, webhooks,
  tags, and permission templates.
- **REQ-EXPORT-003** For each discovered project, the run MUST attempt
  component details, measures, measure history, branches, pull requests,
  quality gate status and definition, quality profiles, analyses, issues,
  hotspots, links, and settings.
- **REQ-EXPORT-004** Project work MUST be bounded by the configured
  concurrency limit and MUST process every discovered project unless the run
  fails for a run-level reason.
- **REQ-OUTPUT-001** Successful resources MUST be written as UTF-8,
  pretty-printed JSON with a trailing newline, creating parent directories as
  required.
- **REQ-OUTPUT-002** Organization and project identifiers used in paths MUST
  be converted to safe filename segments; path separators and other unsafe
  characters MUST NOT be interpreted as directory traversal.
- **REQ-OUTPUT-003** The tree MUST separate organization-level resources from
  project-level resources beneath their organization/project identifiers.
- **REQ-OUTPUT-004** The final `manifest.json` MUST include base URL, start and
  finish timestamps, organization keys, project count, request count, file
  count, and recorded resource errors.

### Partial failure behavior

- **REQ-ERROR-001** A failure fetching an individual resource MUST be recorded
  with its output path, HTTP status when available, and an error message, and
  MUST NOT prevent unrelated resources from being attempted.
- **REQ-ERROR-002** HTTP 401, 403, and 404 for an individual resource MUST be
  recorded without routine warning-level noise; unexpected HTTP and network
  errors SHOULD be warned about.
- **REQ-ERROR-003** An unavailable resource MUST not be represented as a
  successful empty response. Its absence and failure reason belong in the
  manifest.
- **REQ-ERROR-004** Failure of authentication validation is a run-level
  failure, not a resource-level skip.

## Security and privacy principles

- **REQ-SEC-001** Secret values MUST NOT be committed, logged, printed in
  errors, serialized into manifests, or included in test fixtures.
- **REQ-SEC-002** Use `macos-keychain-env` for keychain-backed secret
  resolution. Existing environment variables remain the non-macOS / CI path;
  keychain access MUST only be attempted when needed.
- **REQ-SEC-003** A `.env.keychain` manifest MUST be treated as untrusted input
  until reviewed and approved through the package's trust mechanism. The
  specification repository itself MUST NOT copy a source manifest.
- **REQ-SEC-004** Exported data can contain private user, organization,
  project, and security findings. It MUST remain local by default, must be
  excluded from source control by default, and must not be added to this
  specification repository.
- **REQ-SEC-005** Diagnostics and error records MUST avoid including bearer
  credentials or response content that could expose secret material.

## Dependency contracts

### `fetch-undici`

Use the package as the HTTP transport and authentication layer, not as a
second application-level retry or pagination implementation. The observed
source uses `AsyncClient`, `BearerAuth`, finite connect/read timeouts, and
`JitterStrategy.FULL`. Retry policy includes transient server/rate-limit
statuses, exception retries, exponential delay, a maximum delay, and
`Retry-After` support. The adapter above it translates API paths, parses JSON,
and makes HTTP status explicit to exporter-level resource handling.

Reference: <https://github.com/multistageharness/http-fetch-undici>

### `macos-keychain-env`

Use `loadEnv()` (or its documented equivalent) to resolve approved
`keychain://` references into the process environment. Respect environment
variable precedence, trusted-manifest behavior, and platform constraints.
Never read a secret merely to check whether it is present; use the package's
check/presence API when needed.

Reference: <https://github.com/multistageharness/macos-keychain-env>

## Verification model

The accompanying Gherkin scenarios form the behavior-level test plan. They
should be executable against a fake SonarCloud HTTP server and a temporary
output directory wherever possible. Live SonarCloud checks are opt-in, use
user-controlled credentials, and MUST not be required for ordinary local test
runs. Scenarios should assert outcomes and side effects rather than
implementation structure.
