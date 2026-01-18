# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0](https://github.com/andrii-solokh/DuplicateManager/compare/DuplicateManager-v1.1.0...DuplicateManager-v1.2.0) (2026-01-18)


### Features

* **ci:** add Release Please for automated versioning and changelog ([4685a70](https://github.com/andrii-solokh/DuplicateManager/commit/4685a703e9893b835eb871400d93a45a3f7d5687))
* **ci:** add separate release workflow for package promotion ([c8abeeb](https://github.com/andrii-solokh/DuplicateManager/commit/c8abeebaf39d1b79d40aca06b46688ff267e388c))
* **ci:** bump version on every commit to main ([d249b08](https://github.com/andrii-solokh/DuplicateManager/commit/d249b08fc3f884c523a610fdec34649b22b00c91))
* **ci:** simplify release workflow - beta on release PR only ([0e33c73](https://github.com/andrii-solokh/DuplicateManager/commit/0e33c73545b71d318da06706a8b596263105fd57))
* **duplicate-viewer:** add stop scan functionality with improved job tracking ([41947fb](https://github.com/andrii-solokh/DuplicateManager/commit/41947fbd48ed6098e8a801f8a32cc6a4867ddc94))
* initial release of Duplicate Manager ([882009d](https://github.com/andrii-solokh/DuplicateManager/commit/882009da625399b7aeb978232d012cbe4d9ba596))
* **lwc:** add confirmation dialog before starting duplicate scan ([13299e9](https://github.com/andrii-solokh/DuplicateManager/commit/13299e9df5703fdb8099d4d096f7558271aa4fbf))


### Bug Fixes

* **ci:** add contents:write permission for commit comments ([57243e9](https://github.com/andrii-solokh/DuplicateManager/commit/57243e9187d239d5ccf5c0825a6287be510dd799))
* **ci:** create beta package only after release is created ([3c60838](https://github.com/andrii-solokh/DuplicateManager/commit/3c608383ac7bff8ae60b2db0d26da59c48c10066))
* **ci:** fix release-please output handling ([a769ea2](https://github.com/andrii-solokh/DuplicateManager/commit/a769ea25b64bdfc1714214f06e08d1bceac205e0))
* **ci:** improve error handling in package creation workflow ([9c3fa98](https://github.com/andrii-solokh/DuplicateManager/commit/9c3fa98e59a08de1f34159529a557cb9ff773b86))
* **ci:** integrate beta creation into CI workflow ([db4a6f4](https://github.com/andrii-solokh/DuplicateManager/commit/db4a6f4244ee3dc5e655c0c7cf341f1bf0e6a789))
* **ci:** separate beta creation and promotion flows ([e3998b7](https://github.com/andrii-solokh/DuplicateManager/commit/e3998b77a260de0a3e8ce21a0cd559e49368ba28))
* **ci:** trigger promotion on GitHub release publish ([d73998d](https://github.com/andrii-solokh/DuplicateManager/commit/d73998d1503069eb2540108f3e930f3925f66666))
* **ci:** use boolean type for workflow input default ([14b3be1](https://github.com/andrii-solokh/DuplicateManager/commit/14b3be14af87369ec426f26bd89bea994989a3b8))
* set default package directory to true ([106144a](https://github.com/andrii-solokh/DuplicateManager/commit/106144a0c92a28aca5da86fe87c23b9f7acf65c3))
* **test:** correct CSS selectors and async handling in Jest tests ([b37dbe3](https://github.com/andrii-solokh/DuplicateManager/commit/b37dbe3666396983be23f75bc11a7aca7d5115f5))
* use standard state/country fields instead of state codes in test ([273dcc6](https://github.com/andrii-solokh/DuplicateManager/commit/273dcc678050991bef539e54b64a3d01ab7fa537))


### Code Refactoring

* **ci:** combine all release workflows into one ([b8672a6](https://github.com/andrii-solokh/DuplicateManager/commit/b8672a6c9fbc456494f23b056564ec15a4b6138a))
* **ci:** simplify release flow with version bump in Release PR ([7f2ec48](https://github.com/andrii-solokh/DuplicateManager/commit/7f2ec4873c9474b98bb8d96abe8596492d926228))
* **ci:** split into ci.yml and release.yml ([fc45947](https://github.com/andrii-solokh/DuplicateManager/commit/fc45947d7456f32769fedbda3baad53f76f7e039))

## [1.1.0](https://github.com/andrii-solokh/DuplicateManager/compare/v1.0.0...v1.1.0) (2026-01-17)


### Features

* **ci:** bump version on every commit to main ([d249b08](https://github.com/andrii-solokh/DuplicateManager/commit/d249b08fc3f884c523a610fdec34649b22b00c91))
* **duplicate-viewer:** add stop scan functionality with improved job tracking ([41947fb](https://github.com/andrii-solokh/DuplicateManager/commit/41947fbd48ed6098e8a801f8a32cc6a4867ddc94))
* **lwc:** add confirmation dialog before starting duplicate scan ([13299e9](https://github.com/andrii-solokh/DuplicateManager/commit/13299e9df5703fdb8099d4d096f7558271aa4fbf))


### Bug Fixes

* **ci:** create beta package only after release is created ([3c60838](https://github.com/andrii-solokh/DuplicateManager/commit/3c608383ac7bff8ae60b2db0d26da59c48c10066))
* **ci:** separate beta creation and promotion flows ([e3998b7](https://github.com/andrii-solokh/DuplicateManager/commit/e3998b77a260de0a3e8ce21a0cd559e49368ba28))
* **ci:** trigger promotion on GitHub release publish ([d73998d](https://github.com/andrii-solokh/DuplicateManager/commit/d73998d1503069eb2540108f3e930f3925f66666))
* **ci:** use boolean type for workflow input default ([14b3be1](https://github.com/andrii-solokh/DuplicateManager/commit/14b3be14af87369ec426f26bd89bea994989a3b8))
* **test:** correct CSS selectors and async handling in Jest tests ([b37dbe3](https://github.com/andrii-solokh/DuplicateManager/commit/b37dbe3666396983be23f75bc11a7aca7d5115f5))

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
