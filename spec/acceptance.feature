Feature: Export accessible SonarCloud data
  The exporter creates a local JSON snapshot for the authenticated user's
  accessible organizations and projects.

  @REQ-CONFIG-001 @REQ-CONFIG-002 @REQ-CONFIG-003
  Scenario: Apply defaults and allow configuration overrides
    Given SONAR_URL, SONAR_OUT, and SONAR_CONCURRENCY are not set
    When exporter configuration is loaded
    Then the server URL is https://sonarcloud.io
    And the output directory is data/
    And project concurrency is 3
    When those three settings are supplied
    Then the supplied values are used

  @REQ-CONFIG-005 @REQ-EXPORT-001 @REQ-ERROR-004 @REQ-CONFIG-006
  Scenario: Reject invalid credentials before creating export files
    Given the authentication validation endpoint rejects the token
    When an export is started
    Then the run fails with the authentication failure
    And no resource output files are written
    And the HTTP client is closed

  @REQ-CONFIG-004 @REQ-SEC-001 @REQ-SEC-005
  Scenario: Resolve credentials without exposing secret values
    Given SONAR_TOKEN is already present in the process environment
    And a keychain reference is configured
    When the exporter initializes credentials
    Then the environment value takes precedence
    And no secret value is written to logs, errors, or the manifest

  @REQ-SEC-002 @REQ-SEC-003
  Scenario: Require approval before resolving a keychain manifest
    Given a keychain manifest has not been approved or has changed since approval
    When keychain-backed credentials are resolved
    Then the keychain package refuses the untrusted manifest
    And the exporter does not receive an unapproved secret

  @REQ-HTTP-001 @REQ-EXPORT-002 @REQ-EXPORT-003 @REQ-OUTPUT-001 @REQ-OUTPUT-003 @REQ-OUTPUT-004
  Scenario: Export organization and project resources
    Given authentication succeeds
    And the user can access one organization with one project
    And each resource endpoint returns data
    When an export is started
    Then organization and project JSON resources are written under the output directory
    And the manifest lists the organization and project count
    And the manifest request and file counts match the export

  @REQ-HTTP-001 @REQ-HTTP-003
  Scenario: Preserve API path, parameters, and HTTP failure context
    Given an API request targets an endpoint with query parameters
    When the request is sent
    Then the client requests the corresponding /api/ path with those parameters
    And a non-success response exposes its HTTP status and endpoint context

  @REQ-PAGE-001
  Scenario: Follow both Sonar pagination response shapes
    Given one collection endpoint returns paging.total across multiple pages
    And another collection endpoint returns top-level total across multiple pages
    When the collections are exported
    Then all available items are included exactly once
    And requests stop after the final reported page

  @REQ-PAGE-002
  Scenario: Stop pagination on an empty page
    Given a collection response page contains no items
    And pagination metadata claims more items may exist
    When the collection is exported
    Then no further page is requested

  @REQ-PAGE-003
  Scenario: Mark a collection truncated at the server result cap
    Given a collection has more than 10000 discoverable results
    When the exporter reaches the 10000-result cap
    Then the saved collection contains no more than 10000 results
    And the saved collection is marked truncated
    And the truncation note identifies the cap

  @REQ-PAGE-004
  Scenario: Batch metric requests and merge measures
    Given a project has 120 visible metric keys
    When project measures are exported
    Then metric requests contain no more than 50 keys each
    And all returned measures are combined in the project measures resource

  @REQ-EXPORT-004
  Scenario: Keep project concurrency bounded
    Given more projects are discovered than the configured concurrency
    When project resources are exported
    Then the number of active project exports never exceeds the configured limit
    And every discovered project is attempted

  @REQ-ERROR-001 @REQ-ERROR-002 @REQ-ERROR-003
  Scenario: Record a forbidden optional resource and continue
    Given an organization resource endpoint responds with HTTP 403
    And other resource endpoints remain available
    When an export is started
    Then the failed resource is recorded in the manifest with status 403
    And the unavailable resource is not written as a successful empty result
    And unrelated resources are still exported
    And no routine warning is emitted for the expected permission failure

  @REQ-ERROR-001 @REQ-ERROR-002 @REQ-HTTP-003
  Scenario: Warn about unexpected resource failures and continue
    Given a resource endpoint fails with HTTP 500 or a network error
    When an export is started
    Then the failure is recorded with its path and status when available
    And a warning is emitted
    And unrelated resources are still attempted

  @REQ-HTTP-002
  Scenario: Retry a transient rate-limit response
    Given a resource endpoint responds with HTTP 429 and a Retry-After value
    And a later attempt succeeds
    When the resource is requested
    Then the HTTP client retries according to its retry policy
    And the successful resource is written

  @REQ-OUTPUT-002
  Scenario: Sanitize identifiers used in output paths
    Given an organization or project key contains path separators or unsafe characters
    When its resource path is constructed
    Then the identifier is represented by a safe filename segment
    And it cannot escape the configured output directory

  @REQ-CONFIG-006
  Scenario: Close transport after a run-level failure
    Given an unexpected run-level failure occurs after client creation
    When the export terminates
    Then the HTTP client is closed

  @REQ-SEC-001 @REQ-SEC-004 @REQ-SEC-005
  Scenario: Keep generated data and credentials out of the specification repository
    Given the export produces user, organization, or project data
    When specification artifacts are updated
    Then no exported data or secret values are included in this repository
