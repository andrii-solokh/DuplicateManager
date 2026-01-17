/**
 * Creates test Contact records with duplicates for testing duplicate detection.
 * Uses DMLOptions to bypass duplicate rules during insert.
 * 
 * Run with: sf apex run --file scripts/apex/CreateTestDuplicates.apex
 */

// Configuration
Integer TARGET_RECORDS = 5000;
Integer[] GROUP_SIZES = new Integer[]{ 2, 3, 4, 5 };

// Data pools
List<String> firstNames = new List<String>{
    'James', 'John', 'Robert', 'Michael', 'William', 'David', 'Richard', 'Joseph', 'Thomas', 'Charles',
    'Christopher', 'Daniel', 'Matthew', 'Anthony', 'Mark', 'Donald', 'Steven', 'Paul', 'Andrew', 'Joshua',
    'Mary', 'Patricia', 'Jennifer', 'Linda', 'Barbara', 'Elizabeth', 'Susan', 'Jessica', 'Sarah', 'Karen',
    'Lisa', 'Nancy', 'Betty', 'Margaret', 'Sandra', 'Ashley', 'Kimberly', 'Emily', 'Donna', 'Michelle',
    'Alex', 'Jordan', 'Taylor', 'Morgan', 'Casey', 'Riley', 'Quinn', 'Avery', 'Cameron', 'Dakota'
};

List<String> lastNames = new List<String>{
    'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez',
    'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin',
    'Lee', 'Perez', 'Thompson', 'White', 'Harris', 'Sanchez', 'Clark', 'Ramirez', 'Lewis', 'Robinson',
    'Walker', 'Young', 'Allen', 'King', 'Wright', 'Scott', 'Torres', 'Nguyen', 'Hill', 'Flores'
};

Map<String, List<String>> nicknames = new Map<String, List<String>>{
    'James' => new List<String>{ 'Jim', 'Jimmy', 'Jamie' },
    'John' => new List<String>{ 'Johnny', 'Jon', 'Jack' },
    'Robert' => new List<String>{ 'Rob', 'Bob', 'Bobby', 'Robbie' },
    'Michael' => new List<String>{ 'Mike', 'Mikey', 'Mick' },
    'William' => new List<String>{ 'Will', 'Bill', 'Billy' },
    'David' => new List<String>{ 'Dave', 'Davey' },
    'Richard' => new List<String>{ 'Rick', 'Rich', 'Dick' },
    'Joseph' => new List<String>{ 'Joe', 'Joey' },
    'Thomas' => new List<String>{ 'Tom', 'Tommy' },
    'Charles' => new List<String>{ 'Charlie', 'Chuck' },
    'Christopher' => new List<String>{ 'Chris', 'Topher' },
    'Daniel' => new List<String>{ 'Dan', 'Danny' },
    'Matthew' => new List<String>{ 'Matt', 'Matty' },
    'Anthony' => new List<String>{ 'Tony', 'Ant' },
    'Steven' => new List<String>{ 'Steve', 'Stevie' },
    'Jennifer' => new List<String>{ 'Jen', 'Jenny' },
    'Elizabeth' => new List<String>{ 'Liz', 'Beth', 'Lizzy' },
    'Patricia' => new List<String>{ 'Pat', 'Patty', 'Tricia' },
    'Margaret' => new List<String>{ 'Maggie', 'Meg', 'Peggy' },
    'Jessica' => new List<String>{ 'Jess', 'Jessie' },
    'Kimberly' => new List<String>{ 'Kim', 'Kimmy' }
};

List<String> titles = new List<String>{
    'Analyst', 'Sr Analyst', 'Lead Analyst', 'Principal Analyst',
    'Engineer', 'Sr Engineer', 'Lead Engineer', 'Principal Engineer',
    'Developer', 'Sr Developer', 'Lead Developer',
    'Manager', 'Sr Manager', 'Director', 'Sr Director',
    'Consultant', 'Sr Consultant', 'Coordinator', 'Sr Coordinator',
    'Specialist', 'Sr Specialist', 'Associate', 'Sr Associate'
};

List<String> departments = new List<String>{
    'Sales', 'Marketing', 'Engineering', 'Finance', 'HR', 'Operations',
    'IT', 'Legal', 'Customer Success', 'Product', 'Design', 'Support'
};

List<String> domains = new List<String>{ 'example.com', 'test.org', 'sample.net', 'demo.io', 'corp.test' };

// Helper methods
String randomFrom(List<String> items) {
    return items[Math.mod(Math.abs(Crypto.getRandomInteger()), items.size())];
}

String generatePhone() {
    return String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 900) + 100) + '-' +
           String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 900) + 100) + '-' +
           String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 9000) + 1000);
}

String generateEmail(String firstName, String lastName, String domain) {
    return firstName.toLowerCase() + '.' + lastName.toLowerCase() + '@' + domain;
}

String getNameVariant(String firstName, Integer index) {
    if (index == 0) return firstName;
    
    List<String> variants = nicknames.get(firstName);
    if (variants != null && !variants.isEmpty()) {
        return variants[Math.mod(index - 1, variants.size())];
    }
    return firstName;
}

// Generate contacts
List<Contact> contacts = new List<Contact>();
Integer groupId = 0;

System.debug('Generating ' + TARGET_RECORDS + ' test contacts with duplicates...');

while (contacts.size() < TARGET_RECORDS) {
    // Rotate through group sizes (2, 3, 4, 5)
    Integer groupSize = GROUP_SIZES[Math.mod(groupId, GROUP_SIZES.size())];
    
    String firstName = randomFrom(firstNames);
    String lastName = randomFrom(lastNames);
    String domain = randomFrom(domains);
    String email = generateEmail(firstName, lastName, domain);
    String baseDept = randomFrom(departments);
    
    // Create duplicate group
    for (Integer i = 0; i < groupSize && contacts.size() < TARGET_RECORDS; i++) {
        contacts.add(new Contact(
            FirstName = getNameVariant(firstName, i),
            LastName = lastName,
            Email = email,
            Phone = generatePhone(),
            Title = randomFrom(titles),
            Department = (i == 0 || Math.mod(Math.abs(Crypto.getRandomInteger()), 10) > 3) ? baseDept : randomFrom(departments)
        ));
    }
    groupId++;
}

System.debug('Created ' + contacts.size() + ' contacts in ' + groupId + ' duplicate groups');

// Insert with DMLOptions to allow duplicates
Database.DMLOptions dml = new Database.DMLOptions();
dml.DuplicateRuleHeader.allowSave = true;
dml.DuplicateRuleHeader.runAsCurrentUser = true;

// Insert in batches to avoid governor limits
Integer BATCH_SIZE = 200;
Integer successCount = 0;
Integer errorCount = 0;

for (Integer i = 0; i < contacts.size(); i += BATCH_SIZE) {
    Integer endIndex = Math.min(i + BATCH_SIZE, contacts.size());
    List<Contact> batch = new List<Contact>();
    for (Integer j = i; j < endIndex; j++) {
        batch.add(contacts[j]);
    }
    
    List<Database.SaveResult> results = Database.insert(batch, dml);
    
    for (Database.SaveResult sr : results) {
        if (sr.isSuccess()) {
            successCount++;
        } else {
            errorCount++;
            for (Database.Error err : sr.getErrors()) {
                System.debug('Error: ' + err.getMessage());
            }
        }
    }
    
    System.debug('Batch ' + (i / BATCH_SIZE + 1) + ': ' + successCount + ' inserted, ' + errorCount + ' errors');
}

System.debug('=== COMPLETE ===');
System.debug('Total inserted: ' + successCount);
System.debug('Total errors: ' + errorCount);
System.debug('Duplicate groups: ' + groupId);
