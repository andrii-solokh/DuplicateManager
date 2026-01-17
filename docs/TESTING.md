# Testing Guide

This guide covers testing Duplicate Manager, including running tests, creating test data, and best
practices.

## Running Tests

### Apex Tests

#### Run All Tests

```bash
sf apex run test \
  --target-org dm-dev \
  --test-level RunLocalTests \
  --code-coverage \
  --result-format human
```

#### Run Specific Test Class

```bash
sf apex run test \
  --target-org dm-dev \
  --tests DuplicateViewerControllerTest
```

#### Run Multiple Test Classes

```bash
sf apex run test \
  --target-org dm-dev \
  --tests DuplicateViewerControllerTest,DuplicateMergeControllerTest,DuplicateScannerJobTest
```

#### Get Detailed Coverage Report

```bash
sf apex run test \
  --target-org dm-dev \
  --test-level RunLocalTests \
  --code-coverage \
  --result-format json \
  --output-dir test-results
```

### LWC Jest Tests

#### Run All Tests

```bash
npm run test:unit
```

#### Run in Watch Mode

```bash
npm run test:unit:watch
```

#### Run with Coverage

```bash
npm run test:unit:coverage
```

#### Run Specific Test File

```bash
npm run test:unit -- --testPathPattern=duplicateViewer
```

## Test Classes

### DuplicateViewerControllerTest

Tests for the main viewer controller including:

- Getting duplicate sets with various filters
- Getting duplicate items for a set
- Getting object type options
- Deleting duplicate sets
- Running duplicate scans
- Job status tracking
- Scheduling and unscheduling jobs

### DuplicateMergeControllerTest

Tests for the merge controller including:

- Record comparison for different object types
- Field value comparison and formatting
- Merge operations with field selections
- Error handling for invalid inputs
- Address and location field formatting

### DuplicateScannerJobTest

Tests for the scanner job including:

- Job execution for various objects
- Batch size handling
- Error handling for invalid objects
- Scheduler integration
- Job abort and status methods

## Creating Test Data

### Setup Test Data in Apex

The test classes use `@TestSetup` for test data:

```apex
@TestSetup
static void setupTestData() {
    List<Contact> contacts = new List<Contact>();

    // Create potential duplicates
    contacts.add(new Contact(
        FirstName = 'John',
        LastName = 'Duplicate',
        Email = 'john@test.com'
    ));
    contacts.add(new Contact(
        FirstName = 'John',
        LastName = 'Duplicate',
        Email = 'john2@test.com'
    ));

    // Insert with duplicate rules bypassed
    Database.DMLOptions dml = new Database.DMLOptions();
    dml.DuplicateRuleHeader.allowSave = true;
    Database.insert(contacts, dml);
}
```

### Create Test Duplicate Sets

```apex
@IsTest
static void createTestDuplicateSet() {
    // Get an active duplicate rule
    DuplicateRule rule = [
        SELECT Id
        FROM DuplicateRule
        WHERE SobjectType = 'Contact'
        AND IsActive = true
        LIMIT 1
    ];

    // Create duplicate set
    DuplicateRecordSet drs = new DuplicateRecordSet();
    drs.DuplicateRuleId = rule.Id;
    insert drs;

    // Add items
    List<Contact> contacts = [SELECT Id FROM Contact LIMIT 2];
    List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
    for (Contact c : contacts) {
        items.add(new DuplicateRecordItem(
            DuplicateRecordSetId = drs.Id,
            RecordId = c.Id
        ));
    }
    insert items;
}
```

## Test Coverage Requirements

### Minimum Coverage

- Overall: 75% (Salesforce requirement for package creation)
- Target: 90%+ for production quality

### Current Coverage by Class

| Class                     | Coverage |
| ------------------------- | -------- |
| DuplicateViewerController | 95%+     |
| DuplicateMergeController  | 95%+     |
| DuplicateScannerJob       | 90%+     |
| DuplicateScannerScheduler | 95%+     |

## Best Practices

### Apex Tests

1. **Use `@TestSetup`** for shared test data
2. **Test positive and negative cases**
3. **Use meaningful assertions** with `Assert.areEquals()` and messages
4. **Test bulk operations** (200+ records)
5. **Mock external callouts** if needed
6. **Don't rely on org data** - create all test data

### Example Assertions

```apex
// Good
Assert.areEquals(expected, actual, 'Record count should match');
Assert.isTrue(result.success, 'Merge should succeed');
Assert.isNotNull(wrapper.recordId, 'Record ID should be populated');

// Avoid
System.assert(result.success); // No message
System.assertEquals(expected, actual); // Old syntax
```

### LWC Tests

1. **Test component rendering**
2. **Test user interactions**
3. **Test wire adapters with mocks**
4. **Test error states**
5. **Test loading states**

### Example LWC Test

```javascript
import { createElement } from "lwc";
import DuplicateViewer from "c/duplicateViewer";
import getDuplicateSets from "@salesforce/apex/DuplicateViewerController.getDuplicateSets";

jest.mock(
  "@salesforce/apex/DuplicateViewerController.getDuplicateSets",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

describe("c-duplicate-viewer", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("displays loading spinner initially", () => {
    const element = createElement("c-duplicate-viewer", {
      is: DuplicateViewer
    });
    document.body.appendChild(element);

    const spinner = element.shadowRoot.querySelector("lightning-spinner");
    expect(spinner).not.toBeNull();
  });
});
```

## Troubleshooting Tests

### "No active duplicate rules found"

Ensure your scratch org has active duplicate rules:

1. Check Setup → Duplicate Rules
2. Activate the included sample rule
3. Or create a test rule in your test setup

### Tests Fail in CI but Pass Locally

- Check for order-dependent tests
- Verify test data isolation
- Look for timing issues with async operations
- Ensure all mocks are properly configured

### Coverage Not Counting

- Ensure tests use `Test.startTest()` and `Test.stopTest()`
- Check that assertions are meaningful (not just `System.assert(true)`)
- Verify test methods are annotated with `@IsTest`

### LWC Tests Fail

- Check jest mocks are correctly configured
- Verify component imports
- Look for missing async/await
- Check DOM queries use correct selectors
