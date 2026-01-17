# Development Guide

This guide covers local development setup for contributing to Duplicate Manager.

## Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/sfdxcli) (sf or sfdx)
- [Node.js](https://nodejs.org/) (v18 or higher)
- [Git](https://git-scm.com/)
- A Salesforce DevHub org for scratch org creation

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/andriisolokh/DuplicateManager.git
cd DuplicateManager
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Authenticate DevHub

```bash
sf org login web --set-default-dev-hub --alias latdx-dh
```

### 4. Create a Scratch Org

```bash
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias dm-dev \
  --set-default \
  --duration-days 30
```

### 5. Push Source

```bash
sf project deploy start
```

### 6. Assign Permission Set

```bash
sf org assign permset --name Duplicate_Manager
```

### 7. Open the Org

```bash
sf org open
```

## Project Structure

```
DuplicateManager/
├── src/
│   └── main/
│       └── default/
│           ├── classes/           # Apex classes
│           ├── lwc/               # Lightning Web Components
│           │   ├── duplicateViewer/
│           │   └── duplicateMergeModal/
│           ├── permissionsets/    # Permission sets
│           ├── tabs/              # Custom tabs
│           ├── matchingRules/     # Sample matching rules
│           └── duplicateRules/    # Sample duplicate rules
├── config/
│   └── project-scratch-def.json   # Scratch org definition
├── docs/                          # Documentation
├── .github/
│   └── workflows/                 # CI/CD workflows
├── sfdx-project.json              # SFDX project configuration
├── package.json                   # Node dependencies
└── jest.config.js                 # Jest configuration
```

## Development Workflow

### Making Changes

1. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes

3. Push to scratch org to test:
   ```bash
   sf project deploy start
   ```

4. Run tests:
   ```bash
   # Apex tests
   sf apex run test --test-level RunLocalTests --code-coverage
   
   # LWC tests
   npm run test:unit
   ```

5. Commit and push:
   ```bash
   git add .
   git commit -m "feat: your feature description"
   git push origin feature/your-feature-name
   ```

### Pulling Changes from Org

If you make changes in the org UI:

```bash
sf project retrieve start --target-org dm-dev
```

## Running Tests

### Apex Tests

```bash
# Run all tests
sf apex run test --target-org dm-dev --test-level RunLocalTests --code-coverage --result-format human

# Run specific test class
sf apex run test --target-org dm-dev --tests DuplicateViewerControllerTest

# Run with detailed output
sf apex run test --target-org dm-dev --test-level RunLocalTests --code-coverage --result-format json --output-dir test-results
```

### LWC Jest Tests

```bash
# Run all tests
npm run test:unit

# Run in watch mode
npm run test:unit:watch

# Run with coverage
npm run test:unit:coverage
```

## Code Quality

### Linting

```bash
# Run ESLint on LWC
npm run lint

# Auto-fix issues
npm run lint -- --fix
```

### Formatting

```bash
# Format all files
npm run prettier

# Check formatting
npm run prettier:verify
```

## Creating a Package Version

### Development Version (Beta)

```bash
sf package version create \
  --package DuplicateManager \
  --installation-key-bypass \
  --wait 10 \
  --target-dev-hub latdx-dh
```

### Production Version

```bash
sf package version create \
  --package DuplicateManager \
  --installation-key-bypass \
  --wait 10 \
  --target-dev-hub latdx-dh \
  --code-coverage \
  --version-name "ver 1.0" \
  --version-number 1.0.0.NEXT
```

### Promote to Released

```bash
sf package version promote \
  --package DuplicateManager@1.0.0-1 \
  --target-dev-hub latdx-dh
```

## Debugging

### Enable Debug Logs

```bash
sf apex log tail --target-org dm-dev
```

### View Logs in UI

1. Setup → Debug Logs
2. Add your user
3. Reproduce the issue
4. Download and review logs

### LWC Debugging

1. Open Chrome DevTools (F12)
2. Go to Sources tab
3. Find your component under `lightning/n/`
4. Set breakpoints as needed

## Common Tasks

### Reset Scratch Org

```bash
sf org delete scratch --target-org dm-dev --no-prompt
sf org create scratch --definition-file config/project-scratch-def.json --alias dm-dev --set-default
sf project deploy start
sf org assign permset --name Duplicate_Manager
```

### Create Test Data

Use the Developer Console or Anonymous Apex:

```apex
// Create test contacts with duplicate emails
List<Contact> contacts = new List<Contact>();
for (Integer i = 0; i < 5; i++) {
    contacts.add(new Contact(
        FirstName = 'Test' + i,
        LastName = 'Contact',
        Email = 'duplicate@test.com' // Same email = potential duplicate
    ));
}
Database.DMLOptions dml = new Database.DMLOptions();
dml.DuplicateRuleHeader.allowSave = true;
Database.insert(contacts, dml);
```

### Run Duplicate Scan Manually

```apex
// Execute in Anonymous Apex
Id jobId = DuplicateScannerJob.execute('Contact');
System.debug('Job ID: ' + jobId);
```

## Troubleshooting

### "Package not found"

Ensure you're connected to the correct DevHub:
```bash
sf org list --all
sf config set target-dev-hub=latdx-dh
```

### "Push failed"

Check for conflicts:
```bash
sf project deploy preview
```

### "Test coverage too low"

Review coverage report:
```bash
sf apex run test --test-level RunLocalTests --code-coverage --result-format human
```

Focus on uncovered lines in the output.
