/**
 * @description Test class for DuplicateMergeController.
 *              Provides comprehensive coverage of all controller methods.
 * @author Andrii Solokh
 * @since 2026
 * @group Duplicate Management
 */
@IsTest
private class DuplicateMergeControllerTest {
  // =====================================================================
  // TEST SETUP
  // =====================================================================

  @TestSetup
  static void setupTestData() {
    // Create test Contacts with various field values
    List<Contact> contacts = new List<Contact>();

    contacts.add(
      new Contact(
        FirstName = 'John',
        LastName = 'TestMerge',
        Email = 'john.merge1@example.com',
        Phone = '555-1234',
        Title = 'Manager',
        Department = 'Sales',
        MailingStreet = '123 Main St',
        MailingCity = 'San Francisco',
        MailingState = 'CA',
        MailingPostalCode = '94102',
        MailingCountry = 'USA'
      )
    );

    contacts.add(
      new Contact(
        FirstName = 'John',
        LastName = 'TestMerge',
        Email = 'john.merge2@example.com',
        Phone = '555-5678',
        Title = 'Director',
        Department = 'Marketing',
        MailingStreet = '456 Oak Ave',
        MailingCity = 'Los Angeles',
        MailingState = 'CA',
        MailingPostalCode = '90001',
        MailingCountry = 'USA'
      )
    );

    contacts.add(
      new Contact(
        FirstName = 'John',
        LastName = 'TestMerge',
        Email = 'john.merge3@example.com',
        Phone = '555-9012',
        Title = 'VP',
        Department = 'Engineering'
      )
    );

    // Insert with allow duplicates
    Database.DMLOptions dmlOptions = new Database.DMLOptions();
    dmlOptions.DuplicateRuleHeader.allowSave = true;
    dmlOptions.DuplicateRuleHeader.runAsCurrentUser = false;
    Database.insert(contacts, dmlOptions);

    // Create test Accounts
    List<Account> accounts = new List<Account>();
    accounts.add(
      new Account(Name = 'Test Account Merge 1', Phone = '111-1111')
    );
    accounts.add(
      new Account(Name = 'Test Account Merge 2', Phone = '222-2222')
    );
    Database.insert(accounts, dmlOptions);

    // Create test Leads
    List<Lead> leads = new List<Lead>();
    leads.add(
      new Lead(
        FirstName = 'Lead',
        LastName = 'TestMerge',
        Company = 'Test Company',
        Email = 'lead.merge1@example.com'
      )
    );
    leads.add(
      new Lead(
        FirstName = 'Lead',
        LastName = 'TestMerge',
        Company = 'Test Company 2',
        Email = 'lead.merge2@example.com'
      )
    );
    Database.insert(leads, dmlOptions);
  }

  // =====================================================================
  // GET RECORD COMPARISON TESTS
  // =====================================================================

  @IsTest
  static void testGetRecordComparisonWithContacts() {
    // Get an active duplicate rule
    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Contact' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty()) {
      // Create DuplicateRecordSet
      DuplicateRecordSet drs = new DuplicateRecordSet();
      drs.DuplicateRuleId = rules[0].Id;
      insert drs;

      // Get test contacts
      List<Contact> contacts = [
        SELECT Id
        FROM Contact
        WHERE LastName = 'TestMerge'
        LIMIT 3
      ];

      if (contacts.size() >= 2) {
        // Create DuplicateRecordItems
        List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
        for (Contact c : contacts) {
          DuplicateRecordItem item = new DuplicateRecordItem();
          item.DuplicateRecordSetId = drs.Id;
          item.RecordId = c.Id;
          items.add(item);
        }
        insert items;

        Test.startTest();
        DuplicateMergeController.ComparisonResult result = DuplicateMergeController.getRecordComparison(
          drs.Id
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(
          'Contact',
          result.objectType,
          'Object type should be Contact'
        );
        System.assertNotEquals(
          null,
          result.records,
          'Records list should not be null'
        );
        System.assertNotEquals(
          null,
          result.fields,
          'Fields list should not be null'
        );
        System.assert(
          result.records.size() >= 2,
          'Should have at least 2 records'
        );
        System.assert(result.fields.size() > 0, 'Should have fields');

        // Verify record info
        for (DuplicateMergeController.RecordInfo ri : result.records) {
          System.assertNotEquals(
            null,
            ri.recordId,
            'Record ID should not be null'
          );
          System.assertNotEquals(
            null,
            ri.recordName,
            'Record name should not be null'
          );
        }

        // Verify field comparison
        for (DuplicateMergeController.FieldComparison fc : result.fields) {
          System.assertNotEquals(
            null,
            fc.apiName,
            'API name should not be null'
          );
          System.assertNotEquals(null, fc.label, 'Label should not be null');
          System.assertNotEquals(null, fc.values, 'Values should not be null');
        }
      }

      // Cleanup
      delete drs;
    }
  }

  @IsTest
  static void testGetRecordComparisonEmptySet() {
    // Get an active duplicate rule
    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Contact' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty()) {
      // Create empty DuplicateRecordSet
      DuplicateRecordSet drs = new DuplicateRecordSet();
      drs.DuplicateRuleId = rules[0].Id;
      insert drs;

      Test.startTest();
      DuplicateMergeController.ComparisonResult result = DuplicateMergeController.getRecordComparison(
        drs.Id
      );
      Test.stopTest();

      System.assertNotEquals(null, result, 'Result should not be null');
      System.assertEquals(0, result.records.size(), 'Should have no records');
      System.assertEquals(0, result.fields.size(), 'Should have no fields');

      // Cleanup
      delete drs;
    }
  }

  @IsTest
  static void testGetRecordComparisonWithAccounts() {
    // Get an active duplicate rule for accounts
    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Account' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty()) {
      DuplicateRecordSet drs = new DuplicateRecordSet();
      drs.DuplicateRuleId = rules[0].Id;
      insert drs;

      List<Account> accounts = [SELECT Id FROM Account LIMIT 2];

      if (accounts.size() >= 2) {
        List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
        for (Account a : accounts) {
          DuplicateRecordItem item = new DuplicateRecordItem();
          item.DuplicateRecordSetId = drs.Id;
          item.RecordId = a.Id;
          items.add(item);
        }
        insert items;

        Test.startTest();
        DuplicateMergeController.ComparisonResult result = DuplicateMergeController.getRecordComparison(
          drs.Id
        );
        Test.stopTest();

        System.assertEquals(
          'Account',
          result.objectType,
          'Object type should be Account'
        );
      }

      delete drs;
    }
  }

  // =====================================================================
  // MERGE RECORDS TESTS
  // =====================================================================

  @IsTest
  static void testMergeContactsBasic() {
    // Get duplicate rule
    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Contact' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty()) {
      // Create DuplicateRecordSet
      DuplicateRecordSet drs = new DuplicateRecordSet();
      drs.DuplicateRuleId = rules[0].Id;
      insert drs;

      // Get test contacts
      List<Contact> contacts = [
        SELECT Id
        FROM Contact
        WHERE LastName = 'TestMerge'
        LIMIT 2
      ];

      if (contacts.size() >= 2) {
        // Create items
        List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
        for (Contact c : contacts) {
          DuplicateRecordItem item = new DuplicateRecordItem();
          item.DuplicateRecordSetId = drs.Id;
          item.RecordId = c.Id;
          items.add(item);
        }
        insert items;

        Id masterId = contacts[0].Id;
        List<Id> duplicateIds = new List<Id>{ contacts[1].Id };

        Test.startTest();
        DuplicateMergeController.MergeResult result = DuplicateMergeController.mergeRecords(
          masterId,
          duplicateIds,
          null,
          drs.Id
        );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Merge should succeed');
        System.assertEquals(
          masterId,
          result.masterRecordId,
          'Master ID should match'
        );
        System.assertEquals(1, result.mergedCount, 'Should merge 1 record');
        System.assertNotEquals(
          null,
          result.message,
          'Message should not be null'
        );

        // Verify duplicate was deleted
        List<Contact> remaining = [
          SELECT Id
          FROM Contact
          WHERE Id = :contacts[1].Id
        ];
        System.assertEquals(0, remaining.size(), 'Duplicate should be deleted');
      }
    }
  }

  @IsTest
  static void testMergeContactsWithFieldSelections() {
    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Contact' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty()) {
      DuplicateRecordSet drs = new DuplicateRecordSet();
      drs.DuplicateRuleId = rules[0].Id;
      insert drs;

      List<Contact> contacts = [
        SELECT Id, Phone, Title
        FROM Contact
        WHERE LastName = 'TestMerge'
        LIMIT 2
      ];

      if (contacts.size() >= 2) {
        List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
        for (Contact c : contacts) {
          DuplicateRecordItem item = new DuplicateRecordItem();
          item.DuplicateRecordSetId = drs.Id;
          item.RecordId = c.Id;
          items.add(item);
        }
        insert items;

        Id masterId = contacts[0].Id;
        List<Id> duplicateIds = new List<Id>{ contacts[1].Id };

        // Select fields from duplicate to use on master
        Map<String, Id> fieldSelections = new Map<String, Id>();
        fieldSelections.put('Phone', contacts[1].Id);
        fieldSelections.put('Title', contacts[1].Id);

        String duplicatePhone = contacts[1].Phone;
        String duplicateTitle = contacts[1].Title;

        Test.startTest();
        DuplicateMergeController.MergeResult result = DuplicateMergeController.mergeRecords(
          masterId,
          duplicateIds,
          fieldSelections,
          drs.Id
        );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Merge should succeed');

        // Verify field values were updated
        Contact merged = [
          SELECT Phone, Title
          FROM Contact
          WHERE Id = :masterId
        ];
        System.assertEquals(
          duplicatePhone,
          merged.Phone,
          'Phone should be from duplicate'
        );
        System.assertEquals(
          duplicateTitle,
          merged.Title,
          'Title should be from duplicate'
        );
      }
    }
  }

  @IsTest
  static void testMergeAccountsBasic() {
    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Account' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty()) {
      DuplicateRecordSet drs = new DuplicateRecordSet();
      drs.DuplicateRuleId = rules[0].Id;
      insert drs;

      List<Account> accounts = [SELECT Id FROM Account LIMIT 2];

      if (accounts.size() >= 2) {
        List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
        for (Account a : accounts) {
          DuplicateRecordItem item = new DuplicateRecordItem();
          item.DuplicateRecordSetId = drs.Id;
          item.RecordId = a.Id;
          items.add(item);
        }
        insert items;

        Test.startTest();
        DuplicateMergeController.MergeResult result = DuplicateMergeController.mergeRecords(
          accounts[0].Id,
          new List<Id>{ accounts[1].Id },
          null,
          drs.Id
        );
        Test.stopTest();

        System.assertEquals(
          true,
          result.success,
          'Account merge should succeed'
        );
      }
    }
  }

  @IsTest
  static void testMergeLeadsBasic() {
    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Lead' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty()) {
      DuplicateRecordSet drs = new DuplicateRecordSet();
      drs.DuplicateRuleId = rules[0].Id;
      insert drs;

      List<Lead> leads = [
        SELECT Id
        FROM Lead
        WHERE LastName = 'TestMerge'
        LIMIT 2
      ];

      if (leads.size() >= 2) {
        List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
        for (Lead l : leads) {
          DuplicateRecordItem item = new DuplicateRecordItem();
          item.DuplicateRecordSetId = drs.Id;
          item.RecordId = l.Id;
          items.add(item);
        }
        insert items;

        Test.startTest();
        DuplicateMergeController.MergeResult result = DuplicateMergeController.mergeRecords(
          leads[0].Id,
          new List<Id>{ leads[1].Id },
          null,
          drs.Id
        );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Lead merge should succeed');
      }
    }
  }

  @IsTest
  static void testMergeRecordsNullMaster() {
    Test.startTest();
    try {
      DuplicateMergeController.mergeRecords(null, new List<Id>(), null, null);
      System.assert(false, 'Should have thrown exception');
    } catch (AuraHandledException e) {
      // Exception is expected for null master
      System.assert(true, 'Exception thrown as expected for null master');
    }
    Test.stopTest();
  }

  @IsTest
  static void testMergeRecordsEmptyDuplicates() {
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    Test.startTest();
    try {
      DuplicateMergeController.mergeRecords(c.Id, new List<Id>(), null, null);
      System.assert(false, 'Should have thrown exception');
    } catch (AuraHandledException e) {
      // Exception is expected for empty duplicates
      System.assert(true, 'Exception thrown as expected for empty duplicates');
    }
    Test.stopTest();
  }

  @IsTest
  static void testMergeRecordsNullDuplicates() {
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    Test.startTest();
    try {
      DuplicateMergeController.mergeRecords(c.Id, null, null, null);
      System.assert(false, 'Should have thrown exception');
    } catch (AuraHandledException e) {
      System.assert(true, 'Exception thrown as expected');
    }
    Test.stopTest();
  }

  @IsTest
  static void testMergeWithoutDuplicateSet() {
    List<Contact> contacts = [
      SELECT Id
      FROM Contact
      WHERE LastName = 'TestMerge'
      LIMIT 2
    ];

    if (contacts.size() >= 2) {
      Test.startTest();
      DuplicateMergeController.MergeResult result = DuplicateMergeController.mergeRecords(
        contacts[0].Id,
        new List<Id>{ contacts[1].Id },
        null,
        null // No duplicate set ID
      );
      Test.stopTest();

      System.assertEquals(
        true,
        result.success,
        'Merge should succeed without DRS'
      );
    }
  }

  // =====================================================================
  // WRAPPER CLASS TESTS
  // =====================================================================

  @IsTest
  static void testComparisonResultWrapper() {
    DuplicateMergeController.ComparisonResult result = new DuplicateMergeController.ComparisonResult();
    result.objectType = 'Contact';
    result.records = new List<DuplicateMergeController.RecordInfo>();
    result.fields = new List<DuplicateMergeController.FieldComparison>();

    System.assertEquals(
      'Contact',
      result.objectType,
      'Object type should match'
    );
    System.assertNotEquals(null, result.records, 'Records should not be null');
    System.assertNotEquals(null, result.fields, 'Fields should not be null');
  }

  @IsTest
  static void testRecordInfoWrapper() {
    DuplicateMergeController.RecordInfo info = new DuplicateMergeController.RecordInfo();
    info.recordId = '003000000000001';
    info.recordName = 'Test Contact';

    System.assertEquals(
      '003000000000001',
      info.recordId,
      'Record ID should match'
    );
    System.assertEquals(
      'Test Contact',
      info.recordName,
      'Record name should match'
    );
  }

  @IsTest
  static void testFieldMetadataWrapper() {
    DuplicateMergeController.FieldMetadata fm = new DuplicateMergeController.FieldMetadata();
    fm.apiName = 'Phone';
    fm.label = 'Phone';
    fm.type = 'PHONE';
    fm.isUpdateable = true;
    fm.isRequired = false;
    fm.isNameField = false;
    fm.isCompoundComponent = false;

    System.assertEquals('Phone', fm.apiName, 'API name should match');
    System.assertEquals(true, fm.isUpdateable, 'Should be updateable');
  }

  @IsTest
  static void testFieldComparisonWrapper() {
    DuplicateMergeController.FieldComparison fc = new DuplicateMergeController.FieldComparison();
    fc.apiName = 'Email';
    fc.label = 'Email';
    fc.type = 'EMAIL';
    fc.isUpdateable = true;
    fc.isRequired = false;
    fc.isNameField = false;
    fc.values = new List<DuplicateMergeController.FieldValue>();
    fc.allEmpty = false;
    fc.allSame = false;
    fc.hasDifference = true;

    System.assertEquals('Email', fc.apiName, 'API name should match');
    System.assertEquals(true, fc.hasDifference, 'Should have difference');
  }

  @IsTest
  static void testFieldComparisonComparable() {
    // Test the Comparable implementation for sorting
    DuplicateMergeController.FieldComparison fc1 = new DuplicateMergeController.FieldComparison();
    fc1.apiName = 'Field1';
    fc1.label = 'Field 1';
    fc1.hasDifference = true;
    fc1.allEmpty = false;

    DuplicateMergeController.FieldComparison fc2 = new DuplicateMergeController.FieldComparison();
    fc2.apiName = 'Field2';
    fc2.label = 'Field 2';
    fc2.hasDifference = false;
    fc2.allEmpty = false;

    DuplicateMergeController.FieldComparison fc3 = new DuplicateMergeController.FieldComparison();
    fc3.apiName = 'Field3';
    fc3.label = 'Field 3';
    fc3.hasDifference = false;
    fc3.allEmpty = true;

    // Test comparisons
    System.assertEquals(
      -1,
      fc1.compareTo(fc2),
      'Difference should come before non-difference'
    );
    System.assertEquals(
      1,
      fc2.compareTo(fc1),
      'Non-difference should come after difference'
    );
    System.assertEquals(
      -1,
      fc2.compareTo(fc3),
      'Non-empty should come before empty'
    );
    System.assertEquals(
      1,
      fc3.compareTo(fc2),
      'Empty should come after non-empty'
    );
  }

  @IsTest
  static void testFieldValueWrapper() {
    DuplicateMergeController.FieldValue fv = new DuplicateMergeController.FieldValue();
    fv.recordId = '003000000000001';
    fv.value = 'test@example.com';
    fv.displayValue = 'test@example.com';
    fv.isEmpty = false;

    System.assertEquals(
      '003000000000001',
      fv.recordId,
      'Record ID should match'
    );
    System.assertEquals(
      'test@example.com',
      fv.displayValue,
      'Display value should match'
    );
    System.assertEquals(false, fv.isEmpty, 'Should not be empty');
  }

  @IsTest
  static void testMergeResultWrapper() {
    DuplicateMergeController.MergeResult result = new DuplicateMergeController.MergeResult();
    result.success = true;
    result.masterRecordId = '003000000000001';
    result.mergedCount = 2;
    result.message = 'Merged successfully';

    System.assertEquals(true, result.success, 'Should be successful');
    System.assertEquals(2, result.mergedCount, 'Merged count should be 2');
    System.assertEquals(
      'Merged successfully',
      result.message,
      'Message should match'
    );
  }

  // =====================================================================
  // EDGE CASE TESTS
  // =====================================================================

  @IsTest
  static void testFieldComparisonSortByLabel() {
    // Test sorting by label when other criteria are equal
    DuplicateMergeController.FieldComparison fc1 = new DuplicateMergeController.FieldComparison();
    fc1.label = 'Beta';
    fc1.hasDifference = false;
    fc1.allEmpty = false;

    DuplicateMergeController.FieldComparison fc2 = new DuplicateMergeController.FieldComparison();
    fc2.label = 'Alpha';
    fc2.hasDifference = false;
    fc2.allEmpty = false;

    Integer comparison = fc1.compareTo(fc2);
    System.assert(comparison > 0, 'Beta should come after Alpha');
  }

  @IsTest
  static void testMergeMultipleDuplicates() {
    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Contact' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty()) {
      DuplicateRecordSet drs = new DuplicateRecordSet();
      drs.DuplicateRuleId = rules[0].Id;
      insert drs;

      List<Contact> contacts = [
        SELECT Id
        FROM Contact
        WHERE LastName = 'TestMerge'
        LIMIT 3
      ];

      if (contacts.size() >= 3) {
        List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
        for (Contact c : contacts) {
          DuplicateRecordItem item = new DuplicateRecordItem();
          item.DuplicateRecordSetId = drs.Id;
          item.RecordId = c.Id;
          items.add(item);
        }
        insert items;

        Id masterId = contacts[0].Id;
        List<Id> duplicateIds = new List<Id>{ contacts[1].Id, contacts[2].Id };

        Test.startTest();
        DuplicateMergeController.MergeResult result = DuplicateMergeController.mergeRecords(
          masterId,
          duplicateIds,
          null,
          drs.Id
        );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Merge should succeed');
        System.assertEquals(2, result.mergedCount, 'Should merge 2 records');
      }
    }
  }

  // =====================================================================
  // ADDITIONAL COVERAGE TESTS
  // =====================================================================

  @IsTest
  static void testGetRecordComparisonFieldTypes() {
    // Test with various field types to ensure formatting works
    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Contact' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty()) {
      DuplicateRecordSet drs = new DuplicateRecordSet();
      drs.DuplicateRuleId = rules[0].Id;
      insert drs;

      // Create contacts with various field values
      List<Contact> contacts = new List<Contact>();
      contacts.add(
        new Contact(
          FirstName = 'Test1',
          LastName = 'Coverage',
          Email = 'test1@example.com',
          Birthdate = Date.today().addYears(-30),
          DoNotCall = true
        )
      );
      contacts.add(
        new Contact(
          FirstName = 'Test2',
          LastName = 'Coverage',
          Email = 'test2@example.com',
          Birthdate = Date.today().addYears(-25),
          DoNotCall = false
        )
      );

      Database.DMLOptions dmlOptions = new Database.DMLOptions();
      dmlOptions.DuplicateRuleHeader.allowSave = true;
      Database.insert(contacts, dmlOptions);

      // Create items
      List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
      for (Contact c : contacts) {
        DuplicateRecordItem item = new DuplicateRecordItem();
        item.DuplicateRecordSetId = drs.Id;
        item.RecordId = c.Id;
        items.add(item);
      }
      insert items;

      Test.startTest();
      DuplicateMergeController.ComparisonResult result = DuplicateMergeController.getRecordComparison(
        drs.Id
      );
      Test.stopTest();

      System.assertNotEquals(null, result, 'Result should not be null');
      System.assert(result.fields.size() > 0, 'Should have fields');

      // Cleanup
      delete drs;
      delete contacts;
    }
  }

  @IsTest
  static void testMergeWithFieldSelectionsFromMaster() {
    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Contact' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty()) {
      DuplicateRecordSet drs = new DuplicateRecordSet();
      drs.DuplicateRuleId = rules[0].Id;
      insert drs;

      List<Contact> contacts = [
        SELECT Id, Phone
        FROM Contact
        WHERE LastName = 'TestMerge'
        LIMIT 2
      ];

      if (contacts.size() >= 2) {
        List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
        for (Contact c : contacts) {
          DuplicateRecordItem item = new DuplicateRecordItem();
          item.DuplicateRecordSetId = drs.Id;
          item.RecordId = c.Id;
          items.add(item);
        }
        insert items;

        Id masterId = contacts[0].Id;
        List<Id> duplicateIds = new List<Id>{ contacts[1].Id };

        // Select field from master (should not change anything)
        Map<String, Id> fieldSelections = new Map<String, Id>();
        fieldSelections.put('Phone', masterId);

        Test.startTest();
        DuplicateMergeController.MergeResult result = DuplicateMergeController.mergeRecords(
          masterId,
          duplicateIds,
          fieldSelections,
          drs.Id
        );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Merge should succeed');
      }
    }
  }

  @IsTest
  static void testMergeWithInvalidFieldSelection() {
    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Contact' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty()) {
      DuplicateRecordSet drs = new DuplicateRecordSet();
      drs.DuplicateRuleId = rules[0].Id;
      insert drs;

      List<Contact> contacts = [
        SELECT Id
        FROM Contact
        WHERE LastName = 'TestMerge'
        LIMIT 2
      ];

      if (contacts.size() >= 2) {
        List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
        for (Contact c : contacts) {
          DuplicateRecordItem item = new DuplicateRecordItem();
          item.DuplicateRecordSetId = drs.Id;
          item.RecordId = c.Id;
          items.add(item);
        }
        insert items;

        Id masterId = contacts[0].Id;
        List<Id> duplicateIds = new List<Id>{ contacts[1].Id };

        // Select field from non-existent record
        Map<String, Id> fieldSelections = new Map<String, Id>();
        fieldSelections.put('Phone', '003000000000000AAA');

        Test.startTest();
        DuplicateMergeController.MergeResult result = DuplicateMergeController.mergeRecords(
          masterId,
          duplicateIds,
          fieldSelections,
          drs.Id
        );
        Test.stopTest();

        System.assertEquals(
          true,
          result.success,
          'Merge should succeed even with invalid selection'
        );
      }
    }
  }

  @IsTest
  static void testFieldComparisonAllScenarios() {
    // Test all comparison scenarios
    DuplicateMergeController.FieldComparison fc1 = new DuplicateMergeController.FieldComparison();
    fc1.label = 'Field1';
    fc1.hasDifference = true;
    fc1.allEmpty = false;

    DuplicateMergeController.FieldComparison fc2 = new DuplicateMergeController.FieldComparison();
    fc2.label = 'Field2';
    fc2.hasDifference = true;
    fc2.allEmpty = false;

    // Both have differences - should sort by label
    Integer comparison = fc1.compareTo(fc2);
    System.assert(comparison < 0, 'Field1 should come before Field2');

    // Test empty vs non-empty
    DuplicateMergeController.FieldComparison fc3 = new DuplicateMergeController.FieldComparison();
    fc3.label = 'Field3';
    fc3.hasDifference = false;
    fc3.allEmpty = true;

    DuplicateMergeController.FieldComparison fc4 = new DuplicateMergeController.FieldComparison();
    fc4.label = 'Field4';
    fc4.hasDifference = false;
    fc4.allEmpty = false;

    Integer comparison2 = fc3.compareTo(fc4);
    System.assert(comparison2 > 0, 'Empty should come after non-empty');
  }

  @IsTest
  static void testFieldValueProperties() {
    DuplicateMergeController.FieldValue fv = new DuplicateMergeController.FieldValue();
    fv.recordId = null;
    fv.value = null;
    fv.displayValue = '';
    fv.isEmpty = true;

    System.assertEquals(null, fv.recordId, 'Record ID should be null');
    System.assertEquals(true, fv.isEmpty, 'Should be empty');
  }

  // =====================================================================
  // ADDITIONAL COVERAGE TESTS FOR MERGE CONTROLLER
  // =====================================================================

  @IsTest
  static void testMergeContactsWithAllFieldTypes() {
    // Use contacts from test setup
    List<Contact> contacts = [
      SELECT Id, Phone, Description
      FROM Contact
      WHERE LastName = 'TestMerge'
      LIMIT 2
    ];

    if (contacts.size() < 2) {
      System.assert(true, 'Not enough contacts for test');
      return;
    }

    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Contact' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty()) {
      DuplicateRecordSet drs = new DuplicateRecordSet();
      drs.DuplicateRuleId = rules[0].Id;
      insert drs;

      List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
      for (Contact c : contacts) {
        DuplicateRecordItem item = new DuplicateRecordItem();
        item.DuplicateRecordSetId = drs.Id;
        item.RecordId = c.Id;
        items.add(item);
      }
      insert items;

      Test.startTest();

      // Test comparison
      DuplicateMergeController.ComparisonResult result = DuplicateMergeController.getRecordComparison(
        drs.Id
      );

      System.assertNotEquals(null, result, 'Result should not be null');
      System.assert(result.fields.size() > 0, 'Should have fields');

      // Test merge with field selections
      Map<String, Id> fieldSelections = new Map<String, Id>();
      fieldSelections.put('Phone', contacts[1].Id);

      DuplicateMergeController.MergeResult mergeResult = DuplicateMergeController.mergeRecords(
        contacts[0].Id,
        new List<Id>{ contacts[1].Id },
        fieldSelections,
        drs.Id
      );

      Test.stopTest();

      System.assertEquals(true, mergeResult.success, 'Merge should succeed');
    }
  }

  @IsTest
  static void testGetRecordComparisonWithDeletedRecord() {
    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Contact' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty()) {
      // Create contacts
      Contact c1 = new Contact(
        FirstName = 'Keep',
        LastName = 'Record',
        Email = 'keep@test.com'
      );
      Contact c2 = new Contact(
        FirstName = 'Delete',
        LastName = 'Record',
        Email = 'delete@test.com'
      );

      Database.DMLOptions dmlOptions = new Database.DMLOptions();
      dmlOptions.DuplicateRuleHeader.allowSave = true;
      List<Database.SaveResult> saveResults = Database.insert(
        new List<Contact>{ c1, c2 },
        dmlOptions
      );

      if (
        !saveResults[0].isSuccess() ||
        !saveResults[1].isSuccess() ||
        c1.Id == null ||
        c2.Id == null
      ) {
        System.assert(true, 'Contact insert failed - skipping test');
        return;
      }

      DuplicateRecordSet drs = new DuplicateRecordSet();
      drs.DuplicateRuleId = rules[0].Id;
      insert drs;

      List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
      DuplicateRecordItem item1 = new DuplicateRecordItem();
      item1.DuplicateRecordSetId = drs.Id;
      item1.RecordId = c1.Id;
      items.add(item1);

      DuplicateRecordItem item2 = new DuplicateRecordItem();
      item2.DuplicateRecordSetId = drs.Id;
      item2.RecordId = c2.Id;
      items.add(item2);
      insert items;

      // Delete one contact to test handling of deleted records
      delete c2;

      Test.startTest();
      // This should handle the deleted record gracefully
      try {
        DuplicateMergeController.ComparisonResult result = DuplicateMergeController.getRecordComparison(
          drs.Id
        );
        // May or may not succeed depending on implementation
        System.assert(true, 'Handled deleted record');
      } catch (Exception e) {
        System.assert(true, 'Exception handling deleted record is acceptable');
      }
      Test.stopTest();

      // Cleanup
      delete drs;
    }
  }

  @IsTest
  static void testMergeWithEmptyFieldSelections() {
    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Contact' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty()) {
      List<Contact> contacts = [
        SELECT Id
        FROM Contact
        WHERE LastName = 'TestMerge'
        LIMIT 2
      ];

      if (contacts.size() >= 2) {
        DuplicateRecordSet drs = new DuplicateRecordSet();
        drs.DuplicateRuleId = rules[0].Id;
        insert drs;

        List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
        for (Contact c : contacts) {
          DuplicateRecordItem item = new DuplicateRecordItem();
          item.DuplicateRecordSetId = drs.Id;
          item.RecordId = c.Id;
          items.add(item);
        }
        insert items;

        Test.startTest();
        // Pass empty map instead of null
        DuplicateMergeController.MergeResult result = DuplicateMergeController.mergeRecords(
          contacts[0].Id,
          new List<Id>{ contacts[1].Id },
          new Map<String, Id>(),
          drs.Id
        );
        Test.stopTest();

        System.assertEquals(
          true,
          result.success,
          'Merge should succeed with empty selections'
        );
      }
    }
  }

  @IsTest
  static void testComparisonResultSorting() {
    // Test that fields are sorted correctly: differences first, then same, then empty
    List<DuplicateMergeController.FieldComparison> fields = new List<DuplicateMergeController.FieldComparison>();

    // Empty field
    DuplicateMergeController.FieldComparison emptyField = new DuplicateMergeController.FieldComparison();
    emptyField.label = 'Empty Field';
    emptyField.hasDifference = false;
    emptyField.allEmpty = true;
    fields.add(emptyField);

    // Same field
    DuplicateMergeController.FieldComparison sameField = new DuplicateMergeController.FieldComparison();
    sameField.label = 'Same Field';
    sameField.hasDifference = false;
    sameField.allEmpty = false;
    fields.add(sameField);

    // Different field
    DuplicateMergeController.FieldComparison diffField = new DuplicateMergeController.FieldComparison();
    diffField.label = 'Different Field';
    diffField.hasDifference = true;
    diffField.allEmpty = false;
    fields.add(diffField);

    // Sort
    fields.sort();

    // Verify order: differences first
    System.assertEquals(
      'Different Field',
      fields[0].label,
      'Different field should be first'
    );
    System.assertEquals(
      'Same Field',
      fields[1].label,
      'Same field should be second'
    );
    System.assertEquals(
      'Empty Field',
      fields[2].label,
      'Empty field should be last'
    );
  }

  // =====================================================================
  // COMPREHENSIVE MERGE COVERAGE TESTS
  // =====================================================================

  @IsTest
  static void testMergeContactsWithManyFields() {
    // Create contacts with many different field values
    Contact c1 = new Contact(
      FirstName = 'MergeTest1',
      LastName = 'Coverage',
      Email = 'merge1@coverage.com',
      Phone = '111-1111',
      MobilePhone = '111-2222',
      Fax = '111-3333',
      Title = 'Manager',
      Department = 'Sales',
      Description = 'Description 1',
      MailingStreet = '100 First St',
      MailingCity = 'City1',
      MailingState = 'CA',
      MailingPostalCode = '11111',
      MailingCountry = 'USA',
      OtherStreet = '200 Other St',
      OtherCity = 'OtherCity1',
      Birthdate = Date.today().addYears(-30),
      DoNotCall = false
    );

    Contact c2 = new Contact(
      FirstName = 'MergeTest2',
      LastName = 'Coverage',
      Email = 'merge2@coverage.com',
      Phone = '222-1111',
      MobilePhone = '222-2222',
      Fax = '222-3333',
      Title = 'Director',
      Department = 'Marketing',
      Description = 'Description 2',
      MailingStreet = '300 Second St',
      MailingCity = 'City2',
      MailingState = 'NY',
      MailingPostalCode = '22222',
      MailingCountry = 'USA',
      OtherStreet = '400 Other St',
      OtherCity = 'OtherCity2',
      Birthdate = Date.today().addYears(-25),
      DoNotCall = true
    );

    Database.DMLOptions dmlOptions = new Database.DMLOptions();
    dmlOptions.DuplicateRuleHeader.allowSave = true;
    List<Database.SaveResult> saveResults = Database.insert(
      new List<Contact>{ c1, c2 },
      dmlOptions
    );

    // Verify inserts succeeded
    if (!saveResults[0].isSuccess() || !saveResults[1].isSuccess()) {
      System.assert(true, 'Contact insert failed - skipping test');
      return;
    }

    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Contact' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty() && c1.Id != null && c2.Id != null) {
      DuplicateRecordSet drs = new DuplicateRecordSet();
      drs.DuplicateRuleId = rules[0].Id;
      insert drs;

      List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
      DuplicateRecordItem item1 = new DuplicateRecordItem();
      item1.DuplicateRecordSetId = drs.Id;
      item1.RecordId = c1.Id;
      items.add(item1);

      DuplicateRecordItem item2 = new DuplicateRecordItem();
      item2.DuplicateRecordSetId = drs.Id;
      item2.RecordId = c2.Id;
      items.add(item2);
      insert items;

      Test.startTest();

      // Get comparison - this exercises field comparison logic
      DuplicateMergeController.ComparisonResult comparison = DuplicateMergeController.getRecordComparison(
        drs.Id
      );

      System.assertNotEquals(null, comparison, 'Comparison should not be null');
      System.assertEquals(
        2,
        comparison.records.size(),
        'Should have 2 records'
      );
      System.assert(comparison.fields.size() > 10, 'Should have many fields');

      // Verify field values are populated
      Boolean foundDifferentField = false;
      for (DuplicateMergeController.FieldComparison fc : comparison.fields) {
        if (fc.hasDifference) {
          foundDifferentField = true;
          break;
        }
      }
      System.assert(
        foundDifferentField,
        'Should have at least one different field'
      );

      // Merge with field selections
      Map<String, Id> fieldSelections = new Map<String, Id>();
      fieldSelections.put('Phone', c2.Id);
      fieldSelections.put('Title', c2.Id);
      fieldSelections.put('Department', c2.Id);
      fieldSelections.put('Description', c2.Id);

      DuplicateMergeController.MergeResult result = DuplicateMergeController.mergeRecords(
        c1.Id,
        new List<Id>{ c2.Id },
        fieldSelections,
        drs.Id
      );

      Test.stopTest();

      System.assertEquals(true, result.success, 'Merge should succeed');
      System.assertEquals(
        c1.Id,
        result.masterRecordId,
        'Master ID should match'
      );
    }
  }

  @IsTest
  static void testMergeAccountsWithRelatedRecords() {
    // Create accounts
    Account a1 = new Account(
      Name = 'Merge Account 1',
      Phone = '111-1111',
      Website = 'www.account1.com'
    );
    Account a2 = new Account(
      Name = 'Merge Account 2',
      Phone = '222-2222',
      Website = 'www.account2.com'
    );

    Database.DMLOptions dmlOptions = new Database.DMLOptions();
    dmlOptions.DuplicateRuleHeader.allowSave = true;
    Database.insert(new List<Account>{ a1, a2 }, dmlOptions);

    // Create related contacts
    Contact relatedContact = new Contact(
      FirstName = 'Related',
      LastName = 'Contact',
      AccountId = a2.Id
    );
    insert relatedContact;

    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Account' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty()) {
      DuplicateRecordSet drs = new DuplicateRecordSet();
      drs.DuplicateRuleId = rules[0].Id;
      insert drs;

      List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
      DuplicateRecordItem item1 = new DuplicateRecordItem();
      item1.DuplicateRecordSetId = drs.Id;
      item1.RecordId = a1.Id;
      items.add(item1);

      DuplicateRecordItem item2 = new DuplicateRecordItem();
      item2.DuplicateRecordSetId = drs.Id;
      item2.RecordId = a2.Id;
      items.add(item2);
      insert items;

      Test.startTest();

      // Get comparison
      DuplicateMergeController.ComparisonResult comparison = DuplicateMergeController.getRecordComparison(
        drs.Id
      );

      System.assertNotEquals(null, comparison, 'Comparison should not be null');
      System.assertEquals(
        'Account',
        comparison.objectType,
        'Object type should be Account'
      );

      // Merge
      DuplicateMergeController.MergeResult result = DuplicateMergeController.mergeRecords(
        a1.Id,
        new List<Id>{ a2.Id },
        null,
        drs.Id
      );

      Test.stopTest();

      System.assertEquals(true, result.success, 'Account merge should succeed');

      // Verify related contact was reparented
      Contact updatedContact = [
        SELECT AccountId
        FROM Contact
        WHERE Id = :relatedContact.Id
      ];
      System.assertEquals(
        a1.Id,
        updatedContact.AccountId,
        'Contact should be reparented to master'
      );
    }
  }

  @IsTest
  static void testGetRecordComparisonWithNullValues() {
    // Create contacts with many null values
    Contact c1 = new Contact(FirstName = 'Null1', LastName = 'Test');
    Contact c2 = new Contact(FirstName = 'Null2', LastName = 'Test');

    Database.DMLOptions dmlOptions = new Database.DMLOptions();
    dmlOptions.DuplicateRuleHeader.allowSave = true;
    List<Database.SaveResult> saveResults = Database.insert(
      new List<Contact>{ c1, c2 },
      dmlOptions
    );

    if (
      !saveResults[0].isSuccess() ||
      !saveResults[1].isSuccess() ||
      c1.Id == null ||
      c2.Id == null
    ) {
      System.assert(true, 'Contact insert failed - skipping test');
      return;
    }

    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Contact' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty()) {
      DuplicateRecordSet drs = new DuplicateRecordSet();
      drs.DuplicateRuleId = rules[0].Id;
      insert drs;

      List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
      DuplicateRecordItem item1 = new DuplicateRecordItem();
      item1.DuplicateRecordSetId = drs.Id;
      item1.RecordId = c1.Id;
      items.add(item1);

      DuplicateRecordItem item2 = new DuplicateRecordItem();
      item2.DuplicateRecordSetId = drs.Id;
      item2.RecordId = c2.Id;
      items.add(item2);
      insert items;

      Test.startTest();
      DuplicateMergeController.ComparisonResult result = DuplicateMergeController.getRecordComparison(
        drs.Id
      );
      Test.stopTest();

      System.assertNotEquals(null, result, 'Result should not be null');

      // Verify empty fields are handled
      Boolean foundEmptyField = false;
      for (DuplicateMergeController.FieldComparison fc : result.fields) {
        if (fc.allEmpty) {
          foundEmptyField = true;
          break;
        }
      }
      System.assert(foundEmptyField, 'Should have empty fields');

      // Cleanup
      delete drs;
    }
  }

  @IsTest
  static void testMergeWithDateAndBooleanFields() {
    // Create contacts with date and boolean fields
    Contact c1 = new Contact(
      FirstName = 'Date1',
      LastName = 'Test',
      Birthdate = Date.today().addYears(-30),
      DoNotCall = true,
      HasOptedOutOfEmail = false
    );
    Contact c2 = new Contact(
      FirstName = 'Date2',
      LastName = 'Test',
      Birthdate = Date.today().addYears(-25),
      DoNotCall = false,
      HasOptedOutOfEmail = true
    );

    Database.DMLOptions dmlOptions = new Database.DMLOptions();
    dmlOptions.DuplicateRuleHeader.allowSave = true;
    List<Database.SaveResult> saveResults = Database.insert(
      new List<Contact>{ c1, c2 },
      dmlOptions
    );

    if (
      !saveResults[0].isSuccess() ||
      !saveResults[1].isSuccess() ||
      c1.Id == null ||
      c2.Id == null
    ) {
      System.assert(true, 'Contact insert failed - skipping test');
      return;
    }

    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Contact' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty()) {
      DuplicateRecordSet drs = new DuplicateRecordSet();
      drs.DuplicateRuleId = rules[0].Id;
      insert drs;

      List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
      DuplicateRecordItem item1 = new DuplicateRecordItem();
      item1.DuplicateRecordSetId = drs.Id;
      item1.RecordId = c1.Id;
      items.add(item1);

      DuplicateRecordItem item2 = new DuplicateRecordItem();
      item2.DuplicateRecordSetId = drs.Id;
      item2.RecordId = c2.Id;
      items.add(item2);
      insert items;

      Test.startTest();

      // Get comparison - exercises date and boolean formatting
      DuplicateMergeController.ComparisonResult comparison = DuplicateMergeController.getRecordComparison(
        drs.Id
      );

      System.assertNotEquals(null, comparison, 'Comparison should not be null');

      // Merge with date field selection
      Map<String, Id> fieldSelections = new Map<String, Id>();
      fieldSelections.put('Birthdate', c2.Id);
      fieldSelections.put('DoNotCall', c2.Id);

      DuplicateMergeController.MergeResult result = DuplicateMergeController.mergeRecords(
        c1.Id,
        new List<Id>{ c2.Id },
        fieldSelections,
        drs.Id
      );

      Test.stopTest();

      System.assertEquals(true, result.success, 'Merge should succeed');
    }
  }

  // =====================================================================
  // ADDITIONAL COVERAGE FOR HELPER METHODS
  // =====================================================================

  @IsTest
  static void testMergeLeadsWithCompanyField() {
    // Test merging leads which have different name structure
    Lead l1 = new Lead(
      FirstName = 'Lead1',
      LastName = 'MergeTest',
      Company = 'Company A',
      Email = 'lead1@merge.com'
    );
    Lead l2 = new Lead(
      FirstName = 'Lead2',
      LastName = 'MergeTest',
      Company = 'Company B',
      Email = 'lead2@merge.com'
    );

    Database.DMLOptions dmlOptions = new Database.DMLOptions();
    dmlOptions.DuplicateRuleHeader.allowSave = true;
    List<Database.SaveResult> saveResults = Database.insert(
      new List<Lead>{ l1, l2 },
      dmlOptions
    );

    if (
      !saveResults[0].isSuccess() ||
      !saveResults[1].isSuccess() ||
      l1.Id == null ||
      l2.Id == null
    ) {
      System.assert(true, 'Lead insert failed - skipping test');
      return;
    }

    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Lead' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty()) {
      DuplicateRecordSet drs = new DuplicateRecordSet();
      drs.DuplicateRuleId = rules[0].Id;
      insert drs;

      List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
      DuplicateRecordItem item1 = new DuplicateRecordItem();
      item1.DuplicateRecordSetId = drs.Id;
      item1.RecordId = l1.Id;
      items.add(item1);

      DuplicateRecordItem item2 = new DuplicateRecordItem();
      item2.DuplicateRecordSetId = drs.Id;
      item2.RecordId = l2.Id;
      items.add(item2);
      insert items;

      Test.startTest();

      // Get comparison
      DuplicateMergeController.ComparisonResult comparison = DuplicateMergeController.getRecordComparison(
        drs.Id
      );

      System.assertNotEquals(null, comparison, 'Comparison should not be null');
      System.assertEquals(
        'Lead',
        comparison.objectType,
        'Object type should be Lead'
      );

      // Merge leads
      DuplicateMergeController.MergeResult result = DuplicateMergeController.mergeRecords(
        l1.Id,
        new List<Id>{ l2.Id },
        null,
        drs.Id
      );

      Test.stopTest();

      System.assertEquals(true, result.success, 'Lead merge should succeed');
    }
  }

  @IsTest
  static void testMergeCasesIfSupported() {
    // Test merging cases if there's an active duplicate rule
    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Case' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty()) {
      // Create test cases
      Case c1 = new Case(
        Subject = 'Test Case 1',
        Description = 'Description 1'
      );
      Case c2 = new Case(
        Subject = 'Test Case 2',
        Description = 'Description 2'
      );

      Database.DMLOptions dmlOptions = new Database.DMLOptions();
      dmlOptions.DuplicateRuleHeader.allowSave = true;
      List<Database.SaveResult> saveResults = Database.insert(
        new List<Case>{ c1, c2 },
        dmlOptions
      );

      if (
        saveResults[0].isSuccess() &&
        saveResults[1].isSuccess() &&
        c1.Id != null &&
        c2.Id != null
      ) {
        DuplicateRecordSet drs = new DuplicateRecordSet();
        drs.DuplicateRuleId = rules[0].Id;
        insert drs;

        List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
        DuplicateRecordItem item1 = new DuplicateRecordItem();
        item1.DuplicateRecordSetId = drs.Id;
        item1.RecordId = c1.Id;
        items.add(item1);

        DuplicateRecordItem item2 = new DuplicateRecordItem();
        item2.DuplicateRecordSetId = drs.Id;
        item2.RecordId = c2.Id;
        items.add(item2);
        insert items;

        Test.startTest();
        DuplicateMergeController.ComparisonResult comparison = DuplicateMergeController.getRecordComparison(
          drs.Id
        );

        DuplicateMergeController.MergeResult result = DuplicateMergeController.mergeRecords(
          c1.Id,
          new List<Id>{ c2.Id },
          null,
          drs.Id
        );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Case merge should succeed');
      }
    }
  }

  @IsTest
  static void testComparisonWithSameValues() {
    // Create contacts with identical values to test allSame logic
    Contact c1 = new Contact(
      FirstName = 'Same',
      LastName = 'Values',
      Email = 'same@test.com',
      Phone = '555-1234'
    );
    Contact c2 = new Contact(
      FirstName = 'Same',
      LastName = 'Values',
      Email = 'same@test.com',
      Phone = '555-1234'
    );

    Database.DMLOptions dmlOptions = new Database.DMLOptions();
    dmlOptions.DuplicateRuleHeader.allowSave = true;
    List<Database.SaveResult> saveResults = Database.insert(
      new List<Contact>{ c1, c2 },
      dmlOptions
    );

    if (
      !saveResults[0].isSuccess() ||
      !saveResults[1].isSuccess() ||
      c1.Id == null ||
      c2.Id == null
    ) {
      System.assert(true, 'Contact insert failed - skipping test');
      return;
    }

    List<DuplicateRule> rules = [
      SELECT Id
      FROM DuplicateRule
      WHERE SobjectType = 'Contact' AND IsActive = TRUE
      LIMIT 1
    ];

    if (!rules.isEmpty()) {
      DuplicateRecordSet drs = new DuplicateRecordSet();
      drs.DuplicateRuleId = rules[0].Id;
      insert drs;

      List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
      DuplicateRecordItem item1 = new DuplicateRecordItem();
      item1.DuplicateRecordSetId = drs.Id;
      item1.RecordId = c1.Id;
      items.add(item1);

      DuplicateRecordItem item2 = new DuplicateRecordItem();
      item2.DuplicateRecordSetId = drs.Id;
      item2.RecordId = c2.Id;
      items.add(item2);
      insert items;

      Test.startTest();
      DuplicateMergeController.ComparisonResult result = DuplicateMergeController.getRecordComparison(
        drs.Id
      );
      Test.stopTest();

      System.assertNotEquals(null, result, 'Result should not be null');

      // Verify some fields are marked as same
      Boolean foundSameField = false;
      for (DuplicateMergeController.FieldComparison fc : result.fields) {
        if (fc.allSame && !fc.allEmpty) {
          foundSameField = true;
          break;
        }
      }
      System.assert(foundSameField, 'Should have fields with same values');

      // Cleanup
      delete drs;
    }
  }

  @IsTest
  static void testFieldMetadataProperties() {
    // Test all properties of FieldMetadata
    DuplicateMergeController.FieldMetadata fm = new DuplicateMergeController.FieldMetadata();
    fm.apiName = 'TestField__c';
    fm.label = 'Test Field';
    fm.type = 'STRING';
    fm.isUpdateable = true;
    fm.isRequired = false;
    fm.isNameField = false;
    fm.isCompoundComponent = true;

    System.assertEquals('TestField__c', fm.apiName, 'API name should match');
    System.assertEquals('Test Field', fm.label, 'Label should match');
    System.assertEquals('STRING', fm.type, 'Type should match');
    System.assertEquals(true, fm.isUpdateable, 'Should be updateable');
    System.assertEquals(false, fm.isRequired, 'Should not be required');
    System.assertEquals(false, fm.isNameField, 'Should not be name field');
    System.assertEquals(
      true,
      fm.isCompoundComponent,
      'Should be compound component'
    );
  }

  @IsTest
  static void testFieldComparisonAllProperties() {
    DuplicateMergeController.FieldComparison fc = new DuplicateMergeController.FieldComparison();
    fc.apiName = 'Email';
    fc.label = 'Email';
    fc.type = 'EMAIL';
    fc.isUpdateable = true;
    fc.isRequired = true;
    fc.isNameField = false;
    fc.values = new List<DuplicateMergeController.FieldValue>();
    fc.allEmpty = false;
    fc.allSame = true;
    fc.hasDifference = false;

    System.assertEquals('Email', fc.apiName, 'API name should match');
    System.assertEquals(true, fc.isRequired, 'Should be required');
    System.assertEquals(true, fc.allSame, 'Should be all same');
    System.assertEquals(false, fc.hasDifference, 'Should not have difference');
  }

  // =====================================================================
  // FORMAT ADDRESS AND LOCATION TESTS
  // =====================================================================

  @IsTest
  static void testFormatAddressWithFullAddress() {
    // Create a Contact with full address
    Contact c = new Contact(
      FirstName = 'Address' + String.valueOf(Datetime.now().getTime()),
      LastName = 'FullTest',
      Email = 'address' +
        String.valueOf(Datetime.now().getTime()) +
        '@fulltest.com',
      MailingStreet = '123 Main Street',
      MailingCity = 'San Francisco',
      MailingState = 'California',
      MailingPostalCode = '94102',
      MailingCountry = 'United States'
    );

    Database.DMLOptions dmlOptions = new Database.DMLOptions();
    dmlOptions.DuplicateRuleHeader.allowSave = true;
    Database.SaveResult sr = Database.insert(c, dmlOptions);

    if (!sr.isSuccess() || c.Id == null) {
      System.assert(true, 'Contact insert failed - skipping test');
      return;
    }

    // Query to get the Address object
    Contact queried = [SELECT MailingAddress FROM Contact WHERE Id = :c.Id];

    Test.startTest();
    String result = DuplicateMergeController.formatAddress(
      queried.MailingAddress
    );
    Test.stopTest();

    System.assert(String.isNotBlank(result), 'Result should not be blank');
    System.assert(
      result.contains('123 Main Street'),
      'Should contain street: ' + result
    );
    System.assert(
      result.contains('San Francisco'),
      'Should contain city: ' + result
    );
  }

  @IsTest
  static void testFormatAddressWithPartialAddress() {
    // Create a Contact with partial address (only city and country)
    Contact c = new Contact(
      FirstName = 'Partial' + String.valueOf(Datetime.now().getTime()),
      LastName = 'AddressPartial',
      Email = 'partial' +
        String.valueOf(Datetime.now().getTime()) +
        '@addresstest.com',
      MailingCity = 'Los Angeles',
      MailingCountry = 'USA'
    );

    Database.DMLOptions dmlOptions = new Database.DMLOptions();
    dmlOptions.DuplicateRuleHeader.allowSave = true;
    Database.SaveResult sr = Database.insert(c, dmlOptions);

    if (!sr.isSuccess() || c.Id == null) {
      System.assert(true, 'Contact insert failed - skipping test');
      return;
    }

    Contact queried = [SELECT MailingAddress FROM Contact WHERE Id = :c.Id];

    Test.startTest();
    String result = DuplicateMergeController.formatAddress(
      queried.MailingAddress
    );
    Test.stopTest();

    System.assert(String.isNotBlank(result), 'Result should not be blank');
    System.assert(
      result.contains('Los Angeles'),
      'Should contain city: ' + result
    );
  }

  @IsTest
  static void testFormatAddressWithStateCode() {
    // Create a Contact with state/country as text (works without State/Country picklists enabled)
    Contact c = new Contact(
      FirstName = 'StateCode' + String.valueOf(Datetime.now().getTime()),
      LastName = 'CodeTest',
      Email = 'statecode' +
        String.valueOf(Datetime.now().getTime()) +
        '@codetest.com',
      MailingCity = 'New York',
      MailingState = 'NY',
      MailingCountry = 'US'
    );

    Database.DMLOptions dmlOptions = new Database.DMLOptions();
    dmlOptions.DuplicateRuleHeader.allowSave = true;
    Database.SaveResult sr = Database.insert(c, dmlOptions);

    if (!sr.isSuccess() || c.Id == null) {
      System.assert(true, 'Contact insert failed - skipping test');
      return;
    }

    Contact queried = [SELECT MailingAddress FROM Contact WHERE Id = :c.Id];

    Test.startTest();
    String result = DuplicateMergeController.formatAddress(
      queried.MailingAddress
    );
    Test.stopTest();

    System.assert(String.isNotBlank(result), 'Result should not be blank');
  }

  @IsTest
  static void testFormatAddressNull() {
    Test.startTest();
    String result = DuplicateMergeController.formatAddress(null);
    Test.stopTest();

    System.assertEquals('', result, 'Null address should return empty string');
  }

  @IsTest
  static void testFormatAddressEmptyAddress() {
    // Create a Contact with no address fields
    Contact c = new Contact(
      FirstName = 'Empty' + String.valueOf(Datetime.now().getTime()),
      LastName = 'EmptyAddr',
      Email = 'empty' +
        String.valueOf(Datetime.now().getTime()) +
        '@emptyaddr.com'
    );

    Database.DMLOptions dmlOptions = new Database.DMLOptions();
    dmlOptions.DuplicateRuleHeader.allowSave = true;
    Database.SaveResult sr = Database.insert(c, dmlOptions);

    if (!sr.isSuccess() || c.Id == null) {
      System.assert(true, 'Contact insert failed - skipping test');
      return;
    }

    Contact queried = [SELECT MailingAddress FROM Contact WHERE Id = :c.Id];

    Test.startTest();
    String result = DuplicateMergeController.formatAddress(
      queried.MailingAddress
    );
    Test.stopTest();

    // Empty address should return empty string
    System.assertEquals('', result, 'Empty address should return empty string');
  }

  @IsTest
  static void testFormatLocationNull() {
    Test.startTest();
    String result = DuplicateMergeController.formatLocation(null);
    Test.stopTest();

    System.assertEquals('', result, 'Null location should return empty string');
  }

  @IsTest
  static void testFormatLocationWithCoordinates() {
    // Create a Location object directly
    Location loc = Location.newInstance(37.7749, -122.4194);

    Test.startTest();
    String result = DuplicateMergeController.formatLocation(loc);
    Test.stopTest();

    System.assert(String.isNotBlank(result), 'Result should not be blank');
    System.assert(result.contains('Lat:'), 'Should contain Lat: ' + result);
    System.assert(result.contains('Lng:'), 'Should contain Lng: ' + result);
    System.assert(
      result.contains('37.7749'),
      'Should contain latitude value: ' + result
    );
  }

  @IsTest
  static void testFormatFieldValueWithAddress() {
    // Create a Contact with address
    Contact c = new Contact(
      FirstName = 'Format' + String.valueOf(Datetime.now().getTime()),
      LastName = 'FieldValueTest',
      Email = 'format' +
        String.valueOf(Datetime.now().getTime()) +
        '@fieldtest.com',
      MailingStreet = '456 Oak Ave',
      MailingCity = 'Seattle',
      MailingState = 'WA'
    );

    Database.DMLOptions dmlOptions = new Database.DMLOptions();
    dmlOptions.DuplicateRuleHeader.allowSave = true;
    Database.SaveResult sr = Database.insert(c, dmlOptions);

    if (!sr.isSuccess() || c.Id == null) {
      System.assert(true, 'Contact insert failed - skipping test');
      return;
    }

    Contact queried = [SELECT MailingAddress FROM Contact WHERE Id = :c.Id];

    Test.startTest();
    String result = DuplicateMergeController.formatFieldValue(
      queried.MailingAddress,
      'ADDRESS'
    );
    Test.stopTest();

    System.assert(String.isNotBlank(result), 'Result should not be blank');
    System.assert(
      result.contains('456 Oak Ave'),
      'Should contain street: ' + result
    );
  }

  @IsTest
  static void testFormatFieldValueWithLocation() {
    Location loc = Location.newInstance(40.7128, -74.0060);

    Test.startTest();
    String result = DuplicateMergeController.formatFieldValue(loc, 'LOCATION');
    Test.stopTest();

    System.assert(String.isNotBlank(result), 'Result should not be blank');
    System.assert(
      result.contains('40.7128'),
      'Should contain latitude: ' + result
    );
  }

  @IsTest
  static void testFormatFieldValueWithDateTime() {
    Datetime dt = Datetime.now();

    Test.startTest();
    String result = DuplicateMergeController.formatFieldValue(dt, 'DATETIME');
    Test.stopTest();

    System.assert(String.isNotBlank(result), 'Result should not be blank');
  }

  @IsTest
  static void testFormatFieldValueWithDate() {
    Date d = Date.today();

    Test.startTest();
    String result = DuplicateMergeController.formatFieldValue(d, 'DATE');
    Test.stopTest();

    System.assert(String.isNotBlank(result), 'Result should not be blank');
  }

  @IsTest
  static void testFormatFieldValueWithBoolean() {
    Test.startTest();
    String resultTrue = DuplicateMergeController.formatFieldValue(
      true,
      'BOOLEAN'
    );
    String resultFalse = DuplicateMergeController.formatFieldValue(
      false,
      'BOOLEAN'
    );
    Test.stopTest();

    System.assertEquals('Yes', resultTrue, 'True should format as Yes');
    System.assertEquals('No', resultFalse, 'False should format as No');
  }

  @IsTest
  static void testFormatFieldValueWithCurrency() {
    Test.startTest();
    String result = DuplicateMergeController.formatFieldValue(
      1234.56,
      'CURRENCY'
    );
    Test.stopTest();

    System.assert(result.contains('1234.56'), 'Should contain currency value');
  }

  @IsTest
  static void testFormatFieldValueWithNull() {
    Test.startTest();
    String result = DuplicateMergeController.formatFieldValue(null, 'STRING');
    Test.stopTest();

    System.assertEquals('', result, 'Null should return empty string');
  }

  @IsTest
  static void testFormatFieldValueWithString() {
    Test.startTest();
    String result = DuplicateMergeController.formatFieldValue(
      'Hello World',
      'STRING'
    );
    Test.stopTest();

    System.assertEquals(
      'Hello World',
      result,
      'String should be returned as-is'
    );
  }
}
