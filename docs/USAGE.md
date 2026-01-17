# Usage Guide

This guide explains how to use Duplicate Manager to find, review, and merge duplicate records.

## Dashboard Overview

The main dashboard provides:

- **Summary Cards**: Quick stats showing total duplicate sets and records by object
- **Object Filter**: Filter duplicates by object type (Contact, Account, Lead, etc.)
- **Duplicate Sets Grid**: Visual cards for each duplicate set
- **Job Status**: Real-time progress when scans are running

## Viewing Duplicates

### Filter by Object Type

1. Use the dropdown at the top to filter by object type
2. Select "All Objects" to see duplicates across all types
3. The grid updates automatically with matching sets

### Understanding Duplicate Sets

Each card shows:

- **Object Badge**: The type of records in the set (Contact, Account, etc.)
- **Record Count**: Number of duplicate records in the set
- **Set Name**: Auto-generated name from Salesforce
- **Rule Name**: The duplicate rule that identified these duplicates
- **Created Date**: When the duplicates were detected

### Viewing Set Details

Click on any duplicate set card to see:

- All records in the duplicate set
- Record names and IDs
- Links to open each record in a new tab

## Running Duplicate Scans

### Manual Scan

1. Select an object type from the filter dropdown
2. Click "Run Duplicate Scan"
3. Monitor progress in the status banner
4. Results appear automatically when complete

**Note**: You must select a specific object type - "All Objects" cannot be scanned.

### Scheduling Automatic Scans

1. Click the clock icon next to "Run Duplicate Scan"
2. Select the time for daily scans
3. Click "Enable Daily Scan"

To modify or cancel:

- Change the time and click "Update Schedule"
- Click "Cancel Schedule" to disable

## Merging Duplicates

### Opening the Merge Modal

1. Click the merge icon on any duplicate set card
2. The merge modal opens with side-by-side comparison

### Selecting the Master Record

1. At the top, click on the record that should be the "master"
2. The master record will be kept; others will be deleted
3. Related records from deleted duplicates are reparented to the master

### Choosing Field Values

The comparison table shows all fields:

- **Differences** (orange): Fields with different values - click to select
- **Same** (green): Fields with identical values across all records
- **Empty** (gray): Fields with no values

To select a value:

1. Click on the cell with the value you want to keep
2. A checkmark appears on selected values
3. Selected values will be copied to the master record

### Filtering Fields

Use the filter buttons to show/hide:

- **Differences**: Fields with different values (shown by default)
- **Same**: Fields with matching values
- **Empty**: Fields with no values

Use the search box to find specific fields.

### Completing the Merge

1. Review your selections
2. Click "Merge Records"
3. Confirm the merge in the dialog
4. Success! View the merged record or close the modal

## Managing Duplicate Sets

### Deleting a Set

If duplicates have been resolved outside the app:

1. Click the delete icon on the set card
2. Confirm deletion
3. This only removes the duplicate set record, not the actual records

### Refreshing Data

Click "Refresh" to reload duplicate sets and summary data.

## Best Practices

### Before Merging

1. **Review all fields** - Don't just look at differences
2. **Check related records** - Understand what will be reparented
3. **Verify the master** - Choose the record with the most complete data
4. **Document decisions** - Note why you chose specific values

### For Large-Scale Cleanup

1. Start with a single object type
2. Sort by record count to find largest duplicate groups
3. Merge in batches to review results
4. Run scans periodically to catch new duplicates

### Scheduling Recommendations

- **High-volume orgs**: Daily scans during off-hours
- **Moderate-volume orgs**: Weekly scans
- **Low-volume orgs**: Monthly scans

## Troubleshooting

### Merge Failed

- Check that you have edit permission on all fields
- Ensure records haven't been deleted since the comparison loaded
- Verify no validation rules are blocking the update

### No Duplicates Found

- Verify duplicate rules are active
- Check that matching rules are configured correctly
- Ensure test data exists that matches your rules

### Slow Performance

- Reduce batch size in scheduled jobs
- Run scans during off-peak hours
- Consider archiving old duplicate sets
