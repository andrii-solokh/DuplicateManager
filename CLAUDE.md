# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DuplicateManager is a Salesforce unlocked package for viewing, managing, and merging duplicate records. Built with Lightning Web Components (LWC) and Apex, it uses Salesforce's native `Datacloud.FindDuplicates` API for duplicate detection.

## Commands

### Deployment

```bash
npm run scratch:create     # Create scratch org with alias DuplicateManager
npm run source:deploy      # Deploy source to default org
npm run permset:assign     # Assign Duplicate_Manager permission set
npm run data:load          # Load test data via scripts/apex/loadTestData.apex
npm run org:open           # Open org in browser
```

### Testing

```bash
npm run test:apex          # Run Apex tests with code coverage
npm run test:unit          # Run LWC Jest tests
npm run test:unit:watch    # Jest in watch mode
npm run test:unit:coverage # Jest with coverage report
```

**After deployment**: Run only Apex tests related to deployed components (not all local tests). Use `sf apex run test --tests <TestClassName> --code-coverage --result-format human` for specific test classes.

### Code Quality

```bash
npm run lint               # ESLint for LWC JavaScript
npm run prettier           # Format all files
npm run prettier:verify    # Check formatting without changes
```

## Architecture

### Apex Layer

**DuplicateViewerController** - Main LWC controller providing:

- `getDuplicateSetPreviews()` - Paginated duplicate sets with preview data
- `runDuplicateScan()` - Triggers async scan job
- `getJobStatus()` / `getRecentJobs()` - Job monitoring
- `scheduleJob()` / `unscheduleJob()` - Schedule management

**DuplicateMergeController** - Merge operations:

- `getRecordComparison()` - Side-by-side field comparison
- `mergeRecords()` - Executes merge with field selection; uses `Database.merge()` for standard objects (Account, Contact, Lead, Case), manual DML for custom objects

**DuplicateScannerJob** (Queueable) - Batch duplicate detection:

- Chains queueable jobs to process large record sets
- Uses `Datacloud.FindDuplicates` (50 records per call limit)
- Cursor-based pagination to overcome 2000 OFFSET limit
- Creates DuplicateRecordSet/DuplicateRecordItem records

**DuplicateScannerScheduler** (Schedulable) - Wraps DuplicateScannerJob for scheduled execution

### LWC Layer

**duplicateViewer** - Main dashboard:

- Displays duplicate sets with pagination (12 per page)
- Object filtering, search, job status polling (2s interval)
- Integrates merge modal and schedule panel

**duplicateMergeModal** - Merge interface:

- Field-by-field comparison across duplicates
- Individual field value selection from any record
- Handles compound fields and custom objects

## Key Technical Details

- **Sharing**: Controllers use `with sharing`; DuplicateScannerJob uses `without sharing` for full org access
- **API Version**: 63.0
- **Test Coverage Threshold**: 80% (branches, functions, lines, statements)
- **FindDuplicates Limit**: 50 records per API call
- **SOQL OFFSET Limit**: 2000 records (handled via cursor-based pagination)

## Code Style

- ESLint extends `@salesforce/eslint-config-lwc/recommended`
- Prettier with Apex/XML/LWC parsers
- Unused variables: prefix with `_` to ignore (e.g., `_event`)
