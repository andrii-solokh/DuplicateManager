// Create duplicate accounts for testing
// Uses DMLOptions to allow duplicates to be created
// Matches Standard Account Matching Rule v1.0 (Name, BillingStreet, BillingCity, Website, Phone)

Database.DMLOptions dml = new Database.DMLOptions();
dml.DuplicateRuleHeader.allowSave = true;
dml.DuplicateRuleHeader.runAsCurrentUser = true;

List<Account> duplicateAccounts = new List<Account>();

// Set 1: Very similar accounts - same name, similar address
duplicateAccounts.add(new Account(
    Name = 'Acme Corporation',
    BillingStreet = '123 Main Street',
    BillingCity = 'San Francisco',
    Phone = '415-555-1000',
    Website = 'www.acme.com'
));
duplicateAccounts.add(new Account(
    Name = 'Acme Corporation',
    BillingStreet = '123 Main St',
    BillingCity = 'San Francisco',
    Phone = '415-555-1001',
    Website = 'www.acme.com'
));
duplicateAccounts.add(new Account(
    Name = 'Acme Corp',
    BillingStreet = '123 Main Street',
    BillingCity = 'San Francisco',
    Phone = '415-555-1000',
    Website = 'acme.com'
));

// Set 2: Similar names and addresses
duplicateAccounts.add(new Account(
    Name = 'Global Tech Solutions',
    BillingStreet = '500 Technology Drive',
    BillingCity = 'Palo Alto',
    Phone = '650-555-2000',
    Website = 'www.globaltechsolutions.com'
));
duplicateAccounts.add(new Account(
    Name = 'Global Tech Solutions Inc',
    BillingStreet = '500 Technology Dr',
    BillingCity = 'Palo Alto',
    Phone = '650-555-2000',
    Website = 'globaltechsolutions.com'
));

// Set 3: Same company different entries
duplicateAccounts.add(new Account(
    Name = 'Johnson & Associates',
    BillingStreet = '789 Business Park Blvd',
    BillingCity = 'Seattle',
    Phone = '206-555-3000',
    Website = 'www.johnsonassociates.com'
));
duplicateAccounts.add(new Account(
    Name = 'Johnson and Associates',
    BillingStreet = '789 Business Park Boulevard',
    BillingCity = 'Seattle',
    Phone = '206-555-3000',
    Website = 'johnsonassociates.com'
));

// Set 4: Matching on multiple fields
duplicateAccounts.add(new Account(
    Name = 'Pacific Northwest Industries',
    BillingStreet = '1000 Industrial Way',
    BillingCity = 'Portland',
    Phone = '503-555-4000',
    Website = 'www.pnwindustries.com'
));
duplicateAccounts.add(new Account(
    Name = 'Pacific Northwest Industries LLC',
    BillingStreet = '1000 Industrial Way',
    BillingCity = 'Portland',
    Phone = '503-555-4001',
    Website = 'pnwindustries.com'
));
duplicateAccounts.add(new Account(
    Name = 'Pacific NW Industries',
    BillingStreet = '1000 Industrial Wy',
    BillingCity = 'Portland',
    Phone = '503-555-4000',
    Website = 'www.pnwindustries.com'
));

// Insert with DML options to allow duplicates
Database.SaveResult[] results = Database.insert(duplicateAccounts, dml);

Integer successCount = 0;
Integer errorCount = 0;

for (Database.SaveResult sr : results) {
    if (sr.isSuccess()) {
        successCount++;
        System.debug('Created: ' + sr.getId());
    } else {
        errorCount++;
        for (Database.Error err : sr.getErrors()) {
            System.debug('Error: ' + err.getMessage());
        }
    }
}

System.debug('=== SUMMARY ===');
System.debug('Created ' + successCount + ' duplicate accounts');
System.debug('Errors: ' + errorCount);
