# SonarQube / SonarCloud Export Specification

This repository distills the attached `sonarcloud-export` project into agent
guidance, behavioral requirements, and test-driven acceptance scenarios. It is
specification-only: it contains no exporter implementation.

The source project exports the SonarCloud data visible to an authenticated user
to a local JSON tree. These documents describe its high-level contract and
important edge cases:

- [Requirements and principles](spec/requirements.md)
- [Acceptance scenarios](spec/acceptance.feature)
- [Observed baseline and open concerns](spec/observed-baseline.md)
- [Agent skill](skills/sonarqube-export-spec/SKILL.md)

The intended HTTP client and secret-provider dependencies are
[`fetch-undici`](https://github.com/multistageharness/http-fetch-undici) and
[`macos-keychain-env`](https://github.com/multistageharness/macos-keychain-env).
Their contracts are referenced here; their source code is not copied.

## Scope boundary

This repository defines behavior and verification expectations. It must not
become an implementation, include exported Sonar data, or contain secret
values. Treat the source repository and its generated output as potentially
sensitive. The attached repository's `.env.keychain` was deliberately not
copied or inspected.
