# Scripts

Utility scripts for development and testing.

## apex/CreateTestDuplicates.apex

Apex script that creates test Contact records with duplicates directly in Salesforce. Uses
`DMLOptions.DuplicateRuleHeader.allowSave = true` to bypass duplicate rules during insert.

### Usage

```bash
sf apex run --file scripts/apex/CreateTestDuplicates.apex
```

Or use VS Code task: **"4. Load Test Data"**

### What It Creates

- **~5000 Contact records** in **~1429 duplicate groups**
- Groups of 2, 3, 4, or 5 duplicates (evenly distributed)
- Same email within each group (triggers duplicate detection)
- Name variations: "Robert" → "Rob", "Bob", "Bobby"
- Varied titles and departments

### Configuration

Edit the script to change the number of records:

```apex
Integer TARGET_RECORDS = 5000;  // Change this value
```

---

## generate-test-data.js (Optional)

Node.js script that generates CSV test data. Can be used with SFDMU if needed.

### Usage

```bash
npm run generate:testdata           # default 5000 records
node scripts/generate-test-data.js 10000  # custom count
```

### Output

Writes to `data/Contact.csv` for use with SFDMU or data import tools.

---

## How Duplicates Are Created

Records in the same duplicate group share the **same email address** but may have:

- **Name variations**: "Robert" → "Rob", "Bob", "Bobby"
- **Different titles**: "Engineer" vs "Sr Engineer"
- **Different departments**: occasionally varied
- **Different phone numbers**: always unique

This simulates real-world duplicate scenarios where the same person appears multiple times with
slightly different data.
