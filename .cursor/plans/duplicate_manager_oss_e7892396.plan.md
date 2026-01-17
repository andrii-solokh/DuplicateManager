---
name: Duplicate Manager OSS
overview: Extract the Duplicate Manager functionality from Teachiq-dedup into a new standalone open-source Salesforce unlocked package repository at ~/Projects/DuplicateManager, with complete documentation and GitHub CI/CD pipelines.
todos:
  - id: create-repo-structure
    content: Create new repository directory structure at ~/Projects/DuplicateManager
    status: pending
  - id: copy-apex-classes
    content: Copy and clean Apex classes (controllers, job, scheduler, tests)
    status: pending
    dependencies:
      - create-repo-structure
  - id: copy-lwc-components
    content: Copy LWC components (duplicateViewer, duplicateMergeModal)
    status: pending
    dependencies:
      - create-repo-structure
  - id: copy-metadata
    content: Copy metadata (tab, permission set, matching/duplicate rules, list views)
    status: pending
    dependencies:
      - create-repo-structure
  - id: create-sfdx-project
    content: Create sfdx-project.json configured for unlocked package with latdx-dh devhub
    status: pending
    dependencies:
      - create-repo-structure
  - id: create-scratch-def
    content: Create project-scratch-def.json with required features
    status: pending
    dependencies:
      - create-repo-structure
  - id: create-github-workflows
    content: Create GitHub Actions workflows (validate-pr, create-package, scratch-org-test)
    status: pending
    dependencies:
      - create-repo-structure
  - id: create-readme
    content: Create comprehensive README.md with features, installation, badges
    status: pending
    dependencies:
      - copy-apex-classes
      - copy-lwc-components
  - id: create-docs
    content: Create documentation (GETTING_STARTED, USAGE, DEVELOPMENT, TESTING)
    status: pending
    dependencies:
      - copy-apex-classes
      - copy-lwc-components
  - id: create-contributing
    content: Create CONTRIBUTING.md with guidelines and code standards
    status: pending
    dependencies:
      - create-repo-structure
  - id: create-supporting-files
    content: Create LICENSE, CHANGELOG, package.json, jest.config.js, .gitignore, .forceignore
    status: pending
    dependencies:
      - create-repo-structure
  - id: init-git-repo
    content: Initialize git repository and make initial commit
    status: pending
    dependencies:
      - create-readme
      - create-docs
      - create-contributing
      - create-supporting-files
      - create-github-workflows
      - create-sfdx-project
      - copy-metadata
---

# Duplicate Manager - Open Source Extraction Plan

## Overview

Extract duplicate management components from the Teachiq-dedup project into a new standalone open-source Salesforce unlocked package. The package will provide a modern UI for viewing, managing, and merging duplicate records using Salesforce's native duplicate detection API.

## Components to Extract

### Apex Classes (4 main + 4 tests)

- `DuplicateViewerController.cls` - LWC controller for viewing duplicate sets
- `DuplicateMergeController.cls` - Controller for record comparison and merging
- `DuplicateScannerJob.cls` - Queueable job for batch duplicate scanning
- `DuplicateScannerScheduler.cls` - Schedulable wrapper for periodic scans
- Corresponding test classes for all above

### LWC Components (2)

- `duplicateViewer` - Main UI component for viewing and managing duplicates
- `duplicateMergeModal` - Side-by-side record comparison and merge modal

### Metadata

- `Duplicate_Manager.tab-meta.xml` - Custom tab
- `Duplicate_Manager.permissionset-meta.xml` - Permission set
- Sample matching rules (Contact email example)
- Sample duplicate rules (Contact email example)
- List view for DuplicateRecordSet

## Repository Structure

```
~/Projects/DuplicateManager/
├── README.md
├── LICENSE (MIT)
├── CONTRIBUTING.md
├── CHANGELOG.md
├── sfdx-project.json
├── package.json
├── jest.config.js
├── .forceignore
├── .gitignore
├── config/
│   └── project-scratch-def.json
├── docs/
│   ├── GETTING_STARTED.md
│   ├── USAGE.md
│   ├── DEVELOPMENT.md
│   └── TESTING.md
├── .github/
│   └── workflows/
│       ├── validate-pr.yml
│       ├── create-package.yml
│       └── scratch-org-test.yml
└── src/
    └── main/
        └── default/
            ├── classes/
            │   ├── DuplicateViewerController.cls
            │   ├── DuplicateMergeController.cls
            │   ├── DuplicateScannerJob.cls
            │   ├── DuplicateScannerScheduler.cls
            │   └── tests/
            ├── lwc/
            │   ├── duplicateViewer/
            │   └── duplicateMergeModal/
            ├── permissionsets/
            ├── tabs/
            ├── matchingRules/
            └── duplicateRules/
```

## Key Configuration

### sfdx-project.json (Unlocked Package)

```json
{
  "packageDirectories": [{
    "path": "src",
    "default": true,
    "package": "DuplicateManager",
    "versionName": "ver 1.0",
    "versionNumber": "1.0.0.NEXT"
  }],
  "namespace": "",
  "sfdcLoginUrl": "https://login.salesforce.com",
  "sourceApiVersion": "63.0"
}
```

### DevHub Configuration

- Use `latdx-dh` as the DevHub alias for package creation

## GitHub Workflows

1. **validate-pr.yml** - Validate metadata on PRs, run Apex tests
2. **create-package.yml** - Create/promote unlocked package versions
3. **scratch-org-test.yml** - Full scratch org validation with test execution

## Documentation Structure

1. **README.md** - Overview, features, quick install, badges
2. **GETTING_STARTED.md** - Installation, post-install setup
3. **USAGE.md** - How to use the duplicate manager UI, scheduling scans
4. **DEVELOPMENT.md** - Local dev setup, contributing workflow
5. **TESTING.md** - Running tests, test data setup
6. **CONTRIBUTING.md** - Contribution guidelines, code standards

## Implementation Steps

The implementation will copy source files, clean company-specific references, configure unlocked package, and create all documentation and CI/CD workflows.