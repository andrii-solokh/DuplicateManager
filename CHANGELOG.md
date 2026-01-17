# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0](https://github.com/andrii-solokh/DuplicateManager/compare/v1.0.0...v1.1.0) (2026-01-17)


### Features

* **lwc:** add confirmation dialog before starting duplicate scan ([13299e9](https://github.com/andrii-solokh/DuplicateManager/commit/13299e9df5703fdb8099d4d096f7558271aa4fbf))


### Bug Fixes

* **test:** correct CSS selectors and async handling in Jest tests ([b37dbe3](https://github.com/andrii-solokh/DuplicateManager/commit/b37dbe3666396983be23f75bc11a7aca7d5115f5))

## 1.0.0 (2026-01-17)

### Features

- **ci:** add Release Please for automated versioning and changelog
  ([4685a70](https://github.com/andrii-solokh/DuplicateManager/commit/4685a703e9893b835eb871400d93a45a3f7d5687))
- **ci:** add separate release workflow for package promotion
  ([c8abeeb](https://github.com/andrii-solokh/DuplicateManager/commit/c8abeebaf39d1b79d40aca06b46688ff267e388c))
- initial release of Duplicate Manager
  ([882009d](https://github.com/andrii-solokh/DuplicateManager/commit/882009da625399b7aeb978232d012cbe4d9ba596))

### Bug Fixes

- **ci:** add contents:write permission for commit comments
  ([57243e9](https://github.com/andrii-solokh/DuplicateManager/commit/57243e9187d239d5ccf5c0825a6287be510dd799))
- **ci:** improve error handling in package creation workflow
  ([9c3fa98](https://github.com/andrii-solokh/DuplicateManager/commit/9c3fa98e59a08de1f34159529a557cb9ff773b86))
- set default package directory to true
  ([106144a](https://github.com/andrii-solokh/DuplicateManager/commit/106144a0c92a28aca5da86fe87c23b9f7acf65c3))
- use standard state/country fields instead of state codes in test
  ([273dcc6](https://github.com/andrii-solokh/DuplicateManager/commit/273dcc678050991bef539e54b64a3d01ab7fa537))

## [1.0.0](https://github.com/andrii-solokh/DuplicateManager/releases/tag/v1.0.0) (2026-01-17)

### Features

- Initial release of Duplicate Manager
- Modern UI dashboard for viewing duplicate record sets
- Side-by-side record comparison with field-by-field merge capability
- Support for Contact, Account, Lead, and Case merging
- Automated duplicate scanning via Queueable job
- Schedulable wrapper for periodic duplicate scans (daily/weekly/monthly)
- Permission set for managing access to duplicate functionality
- Sample matching rule for Contact email matching
- Sample duplicate rule for Contact email duplicates
- Comprehensive Apex test coverage (>90%)
- Full documentation including installation, usage, and development guides
