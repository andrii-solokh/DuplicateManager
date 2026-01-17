# Getting Started with Duplicate Manager

This guide will help you install and configure Duplicate Manager in your Salesforce org.

## Prerequisites

Before installing Duplicate Manager, ensure your org meets these requirements:

1. **Salesforce Edition**: Enterprise, Performance, Unlimited, or Developer
2. **API Version**: 59.0 or higher
3. **Duplicate Management**: Must be enabled in your org
4. **Lightning Experience**: Must be enabled

## Installation

### Install from Package

The easiest way to install is using the managed package:

```bash
# Production or Developer org
sf package install --package DuplicateManager@1.0.0-1 --target-org your-org-alias --wait 10

# Sandbox
sf package install --package DuplicateManager@1.0.0-1 --target-org your-sandbox-alias --wait 10
```

### Install from Source

For development or customization:

```bash
# Clone the repository
git clone https://github.com/andriisolokh/DuplicateManager.git
cd DuplicateManager

# Create a scratch org (optional)
sf org create scratch --definition-file config/project-scratch-def.json --alias dm-dev --set-default --duration-days 30

# Deploy to your org
sf project deploy start --target-org your-org-alias

# Assign permission set
sf org assign permset --name Duplicate_Manager --target-org your-org-alias
```

## Post-Installation Setup

### 1. Assign Permission Set

Users need the `Duplicate_Manager` permission set to access the functionality:

**Via CLI:**
```bash
sf org assign permset --name Duplicate_Manager --target-org your-org-alias
```

**Via Setup:**
1. Go to Setup → Users → Permission Sets
2. Click on "Duplicate Manager"
3. Click "Manage Assignments"
4. Add the users who need access

### 2. Configure Duplicate Rules

Duplicate Manager uses Salesforce's native duplicate detection. You need active duplicate rules:

1. Go to Setup → Duplicate Rules
2. Ensure you have active rules for the objects you want to scan
3. The package includes a sample rule for Contact email matching

### 3. Configure Matching Rules

Matching rules define how records are compared:

1. Go to Setup → Matching Rules
2. Ensure you have active matching rules linked to your duplicate rules
3. The package includes a sample matching rule for Contact email

### 4. Add to Lightning App

Add the Duplicate Manager tab to your Lightning app:

1. Go to Setup → App Manager
2. Edit your desired app
3. Under "Navigation Items", add "Duplicate Manager"
4. Save and verify the tab appears

## Verification

To verify the installation:

1. Navigate to the Duplicate Manager tab
2. You should see the dashboard with summary cards
3. Select an object type from the dropdown
4. Click "Run Duplicate Scan" to test

## Troubleshooting

### "No active duplicate rules found"

Ensure you have at least one active duplicate rule for the object you're scanning:
1. Go to Setup → Duplicate Rules
2. Create or activate a rule for your object

### Permission errors

Ensure the user has:
- The `Duplicate_Manager` permission set assigned
- Read access to the objects being scanned
- Access to the Duplicate Manager tab

### Scan not finding duplicates

1. Verify your matching rules are configured correctly
2. Check that your duplicate rules are active
3. Ensure test data exists that should match

## Next Steps

- Read the [Usage Guide](USAGE.md) to learn how to use the UI
- Check the [Development Guide](DEVELOPMENT.md) for customization
- Review the [Testing Guide](TESTING.md) for running tests
