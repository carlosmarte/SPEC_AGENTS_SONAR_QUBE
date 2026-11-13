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

  @REQ-CONFIG-007
  Scenario Outline: Reject an invalid concurrency setting at startup
    Given SONAR_CONCURRENCY is set to "<value>"
    When an export is started
    Then startup fails with a message naming SONAR_CONCURRENCY
    And no API request is sent
    And no output files are written

    Examples:
      | value |
      |       |
      | abc   |
      | 0     |
      | -1    |
      | 2.5   |

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
    And keychain resolution is not attempted, even if the keychain manifest is not approved
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
    And the manifest file count includes manifest.json itself
    And the summary returned to the caller equals the manifest on disk

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

  @REQ-PAGE-005
  Scenario: Page measure history by history points
    Given a project's measure history has 3 metrics and 2500 history points
    And the server returns at most 1000 history points per page
    When the project's measure history is exported
    Then exactly 3 history pages are requested
    And each metric appears exactly once in the saved resource
    And each metric has all 2500 history points in date order
    And the saved resource is not marked truncated

  @REQ-PAGE-006
  Scenario: Mark a capped collection that is not paged
    Given an organization has more project tags than one request can return
    When the organization's project tags are exported
    Then the saved collection is marked truncated
    And the truncation note names the per-request limit

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

  @REQ-ERROR-003
  Scenario: Record a resource whose prerequisite failed
    Given the metric definitions endpoint fails
    And the user can access one project
    When an export is started
    Then the project's measures are recorded as failed in the manifest
    And no project measures file containing an empty measure list is written

  @REQ-ERROR-005
  Scenario: Fail the run when organizations cannot be listed
    Given authentication succeeds
    And the organization search endpoint fails with HTTP 500
    When an export is started
    Then the run fails with a run-level error
    And it does not report a successful export of zero organizations

  @REQ-ERROR-006
  Scenario Outline: Report the outcome through the exit status
    Given an export run in which <outcome>
    When the process exits
    Then the exit status is <status>

    Examples:
      | outcome                                               | status                         |
      | every resource succeeded                              | zero                           |
      | the only failures were HTTP 401, 403, or 404          | zero                           |
      | a resource failed with HTTP 500 or a network error    | the partial-failure status     |
      | authentication validation failed                      | the run-level failure status   |

  @REQ-SEC-005
  Scenario: Keep raw response bodies out of error records
    Given a resource endpoint fails with a body containing Sonar error messages and other content
    When the failure is recorded
    Then the error record contains the Sonar error messages, length-limited
    And the error record does not contain the rest of the response body

  @REQ-HTTP-002
  Scenario: Retry a transient rate-limit response
    Given a resource endpoint responds with HTTP 429 and a Retry-After value
    And a later attempt succeeds
    When the resource is requested
    Then the HTTP client retries according to its retry policy
    And the successful resource is written

  @REQ-OUTPUT-002
  Scenario Outline: Sanitize identifiers used in output paths
    Given a project key "<key>"
    When its resource path is constructed
    Then the identifier is represented by a single safe filename segment
    And the segment is not empty, "." or ".."
    And it cannot escape the configured output directory

    Examples:
      | key       |
      | ..        |
      | .         |
      | ../../etc |
      | a/b       |
      | a b:c     |

  @REQ-OUTPUT-002
  Scenario: Keep distinct identifiers in distinct paths
    Given one organization has projects with keys "a/b" and "a:b"
    When both projects are exported
    Then each project's resources are written to a different directory
    And neither project's files overwrite the other's

  @REQ-OUTPUT-005
  Scenario: Replace the previous snapshot without leaving stale files
    Given the output directory holds a previous export with a webhooks resource
    And the webhooks endpoint now responds with HTTP 403
    When an export completes
    Then the output directory contains no webhooks resource file
    And the manifest records the webhooks failure

  @REQ-OUTPUT-005
  Scenario: Keep the previous snapshot when a run is interrupted
    Given the output directory holds a previous export
    When a new export fails with a run-level error partway through
    Then the previous export is still present and unchanged

  @REQ-OUTPUT-005
  Scenario: Refuse to replace a directory that is not an export
    Given the configured output directory contains files but no manifest.json
    When an export is started
    Then startup fails without deleting or changing any file in that directory

  @REQ-CONFIG-006
  Scenario: Close transport after a run-level failure
    Given an unexpected run-level failure occurs after client creation
    When the export terminates
    Then the HTTP client is closed

  @REQ-SEC-004 @REQ-OUTPUT-006
  Scenario: Keep exported data private by default
    Given the exporter is run with the default output directory
    When an export completes
    Then the output directory is excluded from source control by default
    And exported directories and files are readable only by the owning user
