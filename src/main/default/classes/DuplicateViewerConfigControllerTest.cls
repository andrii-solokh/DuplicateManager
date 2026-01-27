/**
 * @description Test class for DuplicateViewerConfigController.
 * @author Andrii Solokh
 * @since 2026
 * @group Duplicate Management
 */
@IsTest
private class DuplicateViewerConfigControllerTest {
  // =====================================================================
  // HAS ADMIN ACCESS TESTS
  // =====================================================================

  @IsTest
  static void testHasAdminAccess() {
    Test.startTest();
    Boolean hasAccess = DuplicateViewerConfigController.hasAdminAccess();
    Test.stopTest();

    // Running user should have access in test context
    System.assertNotEquals(
      null,
      hasAccess,
      'hasAdminAccess should return a value'
    );
  }

  // =====================================================================
  // GET AVAILABLE FIELDS TESTS
  // =====================================================================

  @IsTest
  static void testGetAvailableFieldsContact() {
    Test.startTest();
    List<DuplicateViewerConfigController.FieldInfo> fields = DuplicateViewerConfigController.getAvailableFields(
      'Contact'
    );
    Test.stopTest();

    System.assertNotEquals(null, fields, 'Fields should not be null');
    System.assert(fields.size() > 0, 'Contact should have accessible fields');

    // Verify field structure
    Boolean hasEmail = false;
    for (DuplicateViewerConfigController.FieldInfo field : fields) {
      System.assertNotEquals(
        null,
        field.apiName,
        'API name should not be null'
      );
      System.assertNotEquals(null, field.label, 'Label should not be null');
      System.assertNotEquals(
        null,
        field.fieldType,
        'Field type should not be null'
      );
      if (field.apiName == 'Email') {
        hasEmail = true;
      }
    }
    System.assert(hasEmail, 'Contact fields should include Email');
  }

  @IsTest
  static void testGetAvailableFieldsAccount() {
    Test.startTest();
    List<DuplicateViewerConfigController.FieldInfo> fields = DuplicateViewerConfigController.getAvailableFields(
      'Account'
    );
    Test.stopTest();

    System.assertNotEquals(null, fields, 'Fields should not be null');
    System.assert(fields.size() > 0, 'Account should have accessible fields');
  }

  @IsTest
  static void testGetAvailableFieldsBlank() {
    Test.startTest();
    List<DuplicateViewerConfigController.FieldInfo> fields = DuplicateViewerConfigController.getAvailableFields(
      ''
    );
    Test.stopTest();

    System.assertNotEquals(null, fields, 'Fields should not be null');
    System.assertEquals(0, fields.size(), 'Should return empty for blank');
  }

  @IsTest
  static void testGetAvailableFieldsInvalidObject() {
    Test.startTest();
    try {
      DuplicateViewerConfigController.getAvailableFields(
        'NonExistentObject__c'
      );
      System.assert(false, 'Should have thrown exception');
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().contains('Object type not found'),
        'Should report object not found'
      );
    }
    Test.stopTest();
  }

  // =====================================================================
  // GET FIELD CONFIG TESTS
  // =====================================================================

  @IsTest
  static void testGetFieldConfigEmpty() {
    Test.startTest();
    List<DuplicateViewerConfigController.FieldConfigWrapper> configs = DuplicateViewerConfigController.getFieldConfig(
      'Contact'
    );
    Test.stopTest();

    System.assertNotEquals(null, configs, 'Configs should not be null');
    System.assertEquals(0, configs.size(), 'Should be empty when no configs');
  }

  @IsTest
  static void testGetFieldConfigBlank() {
    Test.startTest();
    List<DuplicateViewerConfigController.FieldConfigWrapper> configs = DuplicateViewerConfigController.getFieldConfig(
      ''
    );
    Test.stopTest();

    System.assertNotEquals(null, configs, 'Configs should not be null');
    System.assertEquals(0, configs.size(), 'Should return empty for blank');
  }

  @IsTest
  static void testGetFieldConfigWithData() {
    // Create test config records
    List<Duplicate_Viewer_Config__c> testConfigs = new List<Duplicate_Viewer_Config__c>();
    testConfigs.add(
      new Duplicate_Viewer_Config__c(
        Object_Type__c = 'Contact',
        Field_API_Name__c = 'Email',
        Sort_Order__c = 1,
        Show_In_Preview__c = true,
        Show_As_Filter__c = false
      )
    );
    testConfigs.add(
      new Duplicate_Viewer_Config__c(
        Object_Type__c = 'Contact',
        Field_API_Name__c = 'Phone',
        Sort_Order__c = 2,
        Show_In_Preview__c = true,
        Show_As_Filter__c = true
      )
    );
    insert testConfigs;

    Test.startTest();
    List<DuplicateViewerConfigController.FieldConfigWrapper> configs = DuplicateViewerConfigController.getFieldConfig(
      'Contact'
    );
    Test.stopTest();

    System.assertEquals(2, configs.size(), 'Should return 2 configs');
    System.assertEquals(
      'Email',
      configs[0].fieldApiName,
      'First config should be Email (sorted by Sort_Order)'
    );
    System.assertEquals(
      true,
      configs[0].showInPreview,
      'Email should be shown in preview'
    );
    System.assertEquals(
      'Phone',
      configs[1].fieldApiName,
      'Second config should be Phone'
    );
    System.assertEquals(
      true,
      configs[1].showAsFilter,
      'Phone should be shown as filter'
    );
  }

  // =====================================================================
  // SAVE FIELD CONFIG TESTS
  // =====================================================================

  @IsTest
  static void testSaveFieldConfigNew() {
    String configJson =
      '[' +
      '{"fieldApiName":"Email","sortOrder":1,"showInPreview":true,"showAsFilter":false},' +
      '{"fieldApiName":"Phone","sortOrder":2,"showInPreview":true,"showAsFilter":true}' +
      ']';

    Test.startTest();
    DuplicateViewerConfigController.saveFieldConfig('Contact', configJson);
    Test.stopTest();

    List<Duplicate_Viewer_Config__c> saved = [
      SELECT
        Field_API_Name__c,
        Sort_Order__c,
        Show_In_Preview__c,
        Show_As_Filter__c
      FROM Duplicate_Viewer_Config__c
      WHERE Object_Type__c = 'Contact'
      ORDER BY Sort_Order__c
    ];

    System.assertEquals(2, saved.size(), 'Should have saved 2 configs');
    System.assertEquals(
      'Email',
      saved[0].Field_API_Name__c,
      'First should be Email'
    );
    System.assertEquals(
      'Phone',
      saved[1].Field_API_Name__c,
      'Second should be Phone'
    );
  }

  @IsTest
  static void testSaveFieldConfigUpdate() {
    // Create initial config
    Duplicate_Viewer_Config__c existing = new Duplicate_Viewer_Config__c(
      Object_Type__c = 'Contact',
      Field_API_Name__c = 'Email',
      Sort_Order__c = 1,
      Show_In_Preview__c = true,
      Show_As_Filter__c = false
    );
    insert existing;

    // Update with changed values
    String configJson =
      '[{"id":"' +
      existing.Id +
      '","fieldApiName":"Email","sortOrder":1,"showInPreview":true,"showAsFilter":true}]';

    Test.startTest();
    DuplicateViewerConfigController.saveFieldConfig('Contact', configJson);
    Test.stopTest();

    Duplicate_Viewer_Config__c updated = [
      SELECT Show_As_Filter__c
      FROM Duplicate_Viewer_Config__c
      WHERE Id = :existing.Id
    ];
    System.assertEquals(
      true,
      updated.Show_As_Filter__c,
      'Show_As_Filter should be updated to true'
    );
  }

  @IsTest
  static void testSaveFieldConfigDeleteRemoved() {
    // Create initial configs
    List<Duplicate_Viewer_Config__c> initial = new List<Duplicate_Viewer_Config__c>();
    initial.add(
      new Duplicate_Viewer_Config__c(
        Object_Type__c = 'Contact',
        Field_API_Name__c = 'Email',
        Sort_Order__c = 1,
        Show_In_Preview__c = true,
        Show_As_Filter__c = false
      )
    );
    initial.add(
      new Duplicate_Viewer_Config__c(
        Object_Type__c = 'Contact',
        Field_API_Name__c = 'Phone',
        Sort_Order__c = 2,
        Show_In_Preview__c = true,
        Show_As_Filter__c = false
      )
    );
    insert initial;

    // Save only Email (Phone should be deleted)
    String configJson =
      '[{"id":"' +
      initial[0].Id +
      '","fieldApiName":"Email","sortOrder":1,"showInPreview":true,"showAsFilter":false}]';

    Test.startTest();
    DuplicateViewerConfigController.saveFieldConfig('Contact', configJson);
    Test.stopTest();

    List<Duplicate_Viewer_Config__c> remaining = [
      SELECT Field_API_Name__c
      FROM Duplicate_Viewer_Config__c
      WHERE Object_Type__c = 'Contact'
    ];
    System.assertEquals(1, remaining.size(), 'Should have 1 config remaining');
    System.assertEquals(
      'Email',
      remaining[0].Field_API_Name__c,
      'Email should remain'
    );
  }

  @IsTest
  static void testSaveFieldConfigBlankObjectType() {
    Test.startTest();
    try {
      DuplicateViewerConfigController.saveFieldConfig('', '[]');
      System.assert(false, 'Should have thrown exception');
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().contains('required'),
        'Should report required fields'
      );
    }
    Test.stopTest();
  }

  // =====================================================================
  // DELETE FIELD CONFIG TESTS
  // =====================================================================

  @IsTest
  static void testDeleteFieldConfig() {
    // Create test config
    insert new Duplicate_Viewer_Config__c(
      Object_Type__c = 'Account',
      Field_API_Name__c = 'Industry',
      Sort_Order__c = 1,
      Show_In_Preview__c = true,
      Show_As_Filter__c = false
    );

    Test.startTest();
    DuplicateViewerConfigController.deleteFieldConfig('Account');
    Test.stopTest();

    List<Duplicate_Viewer_Config__c> remaining = [
      SELECT Id
      FROM Duplicate_Viewer_Config__c
      WHERE Object_Type__c = 'Account'
    ];
    System.assertEquals(
      0,
      remaining.size(),
      'All Account configs should be deleted'
    );
  }

  @IsTest
  static void testDeleteFieldConfigBlank() {
    Test.startTest();
    try {
      DuplicateViewerConfigController.deleteFieldConfig('');
      System.assert(false, 'Should have thrown exception');
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().contains('required'),
        'Should report required'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testDeleteFieldConfigNoExisting() {
    Test.startTest();
    // Should not throw when nothing to delete
    DuplicateViewerConfigController.deleteFieldConfig('Lead');
    Test.stopTest();

    System.assert(true, 'Should complete without error');
  }

  // =====================================================================
  // WRAPPER CLASS TESTS
  // =====================================================================

  @IsTest
  static void testFieldInfoWrapper() {
    DuplicateViewerConfigController.FieldInfo info = new DuplicateViewerConfigController.FieldInfo();
    info.apiName = 'Email';
    info.label = 'Email';
    info.fieldType = 'EMAIL';
    info.isFilterable = true;

    System.assertEquals('Email', info.apiName, 'API name should match');
    System.assertEquals('Email', info.label, 'Label should match');
    System.assertEquals('EMAIL', info.fieldType, 'Type should match');
    System.assertEquals(true, info.isFilterable, 'Should be filterable');
  }

  @IsTest
  static void testFieldInfoComparable() {
    DuplicateViewerConfigController.FieldInfo a = new DuplicateViewerConfigController.FieldInfo();
    a.apiName = 'Email';
    a.label = 'Email';

    DuplicateViewerConfigController.FieldInfo b = new DuplicateViewerConfigController.FieldInfo();
    b.apiName = 'Phone';
    b.label = 'Phone';

    System.assert(a.compareTo(b) < 0, 'Email should sort before Phone');
  }

  @IsTest
  static void testFieldConfigWrapper() {
    DuplicateViewerConfigController.FieldConfigWrapper wrapper = new DuplicateViewerConfigController.FieldConfigWrapper();
    wrapper.objectType = 'Contact';
    wrapper.fieldApiName = 'Email';
    wrapper.sortOrder = 1;
    wrapper.showInPreview = true;
    wrapper.showAsFilter = false;

    System.assertEquals(
      'Contact',
      wrapper.objectType,
      'Object type should match'
    );
    System.assertEquals(
      'Email',
      wrapper.fieldApiName,
      'Field API name should match'
    );
    System.assertEquals(1, wrapper.sortOrder, 'Sort order should match');
    System.assertEquals(
      true,
      wrapper.showInPreview,
      'Show in preview should match'
    );
    System.assertEquals(
      false,
      wrapper.showAsFilter,
      'Show as filter should match'
    );
  }
}
