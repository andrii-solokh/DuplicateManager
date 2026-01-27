/**
 * @description Controller for Duplicate Viewer configuration management.
 *              Handles field configuration for preview and filter display.
 * @author Andrii Solokh
 * @since 2026
 * @group Duplicate Management
 */
public with sharing class DuplicateViewerConfigController {
  /**
   * @description Checks if the current user has admin access to manage configurations.
   *              Uses Create access on Duplicate_Viewer_Config__c as a proxy for the admin perm set.
   * @return True if the user has admin access
   */
  @AuraEnabled(cacheable=true)
  public static Boolean hasAdminAccess() {
    return Schema.SObjectType.Duplicate_Viewer_Config__c.isCreateable();
  }

  /**
   * @description Gets all accessible fields for a given object type.
   * @param objectType The SObject API name
   * @return List of FieldInfo with field metadata
   */
  @AuraEnabled
  public static List<FieldInfo> getAvailableFields(String objectType) {
    List<FieldInfo> fields = new List<FieldInfo>();

    if (String.isBlank(objectType)) {
      return fields;
    }

    try {
      Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectType);
      if (sObjType == null) {
        AuraHandledException e = new AuraHandledException(
          'Object type not found: ' + objectType
        );
        e.setMessage('Object type not found: ' + objectType);
        throw e;
      }

      Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe()
        .fields.getMap();

      for (String fieldName : fieldMap.keySet()) {
        Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName)
          .getDescribe();

        // Only include accessible, non-system fields
        if (
          fieldDescribe.isAccessible() &&
          !isSystemField(fieldName, fieldDescribe)
        ) {
          FieldInfo info = new FieldInfo();
          info.apiName = fieldDescribe.getName();
          info.label = fieldDescribe.getLabel();
          info.fieldType = String.valueOf(fieldDescribe.getType());
          info.isFilterable = fieldDescribe.isFilterable();
          fields.add(info);
        }
      }

      // Sort by label
      fields.sort();
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error getting available fields: ' + e.getMessage()
      );
    }

    return fields;
  }

  /**
   * @description Gets the saved field configuration for an object type.
   * @param objectType The SObject API name
   * @return List of FieldConfigWrapper with saved configuration
   */
  @AuraEnabled
  public static List<FieldConfigWrapper> getFieldConfig(String objectType) {
    List<FieldConfigWrapper> configs = new List<FieldConfigWrapper>();

    if (String.isBlank(objectType)) {
      return configs;
    }

    try {
      List<Duplicate_Viewer_Config__c> records = [
        SELECT
          Id,
          Object_Type__c,
          Field_API_Name__c,
          Sort_Order__c,
          Show_In_Preview__c,
          Show_As_Filter__c
        FROM Duplicate_Viewer_Config__c
        WHERE Object_Type__c = :objectType
        ORDER BY Sort_Order__c ASC
      ];

      for (Duplicate_Viewer_Config__c record : records) {
        FieldConfigWrapper wrapper = new FieldConfigWrapper();
        wrapper.id = record.Id;
        wrapper.objectType = record.Object_Type__c;
        wrapper.fieldApiName = record.Field_API_Name__c;
        wrapper.sortOrder = record.Sort_Order__c != null
          ? Integer.valueOf(record.Sort_Order__c)
          : 0;
        wrapper.showInPreview = record.Show_In_Preview__c;
        wrapper.showAsFilter = record.Show_As_Filter__c;
        configs.add(wrapper);
      }
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error getting field configuration: ' + e.getMessage()
      );
    }

    return configs;
  }

  /**
   * @description Saves field configuration for an object type.
   *              Upserts new/changed configs and deletes removed ones.
   * @param objectType The SObject API name
   * @param configJson JSON array of field config objects
   */
  @AuraEnabled
  public static void saveFieldConfig(String objectType, String configJson) {
    if (!Schema.SObjectType.Duplicate_Viewer_Config__c.isCreateable()) {
      AuraHandledException ex = new AuraHandledException(
        'Insufficient permissions to save configuration.'
      );
      ex.setMessage('Insufficient permissions to save configuration.');
      throw ex;
    }

    if (String.isBlank(objectType) || String.isBlank(configJson)) {
      AuraHandledException e = new AuraHandledException(
        'Object type and configuration are required.'
      );
      e.setMessage('Object type and configuration are required.');
      throw e;
    }

    try {
      List<FieldConfigInput> inputs = (List<FieldConfigInput>) JSON.deserialize(
        configJson,
        List<FieldConfigInput>.class
      );

      // Get existing configs for this object type
      Map<Id, Duplicate_Viewer_Config__c> existingMap = new Map<Id, Duplicate_Viewer_Config__c>(
        [
          SELECT Id
          FROM Duplicate_Viewer_Config__c
          WHERE Object_Type__c = :objectType
        ]
      );

      List<Duplicate_Viewer_Config__c> toUpsert = new List<Duplicate_Viewer_Config__c>();
      Set<Id> processedIds = new Set<Id>();

      for (FieldConfigInput input : inputs) {
        Duplicate_Viewer_Config__c record = new Duplicate_Viewer_Config__c();

        if (String.isNotBlank(input.id)) {
          record.Id = Id.valueOf(input.id);
          processedIds.add(record.Id);
        }

        record.Object_Type__c = objectType;
        record.Field_API_Name__c = input.fieldApiName;
        record.Sort_Order__c = input.sortOrder;
        record.Show_In_Preview__c = input.showInPreview;
        record.Show_As_Filter__c = input.showAsFilter;
        toUpsert.add(record);
      }

      // Delete configs that were removed
      List<Duplicate_Viewer_Config__c> toDelete = new List<Duplicate_Viewer_Config__c>();
      for (Id existingId : existingMap.keySet()) {
        if (!processedIds.contains(existingId)) {
          toDelete.add(new Duplicate_Viewer_Config__c(Id = existingId));
        }
      }

      if (!toUpsert.isEmpty()) {
        upsert toUpsert;
      }
      if (!toDelete.isEmpty()) {
        delete toDelete;
      }
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error saving field configuration: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Deletes all field configuration for an object type (reset to defaults).
   * @param objectType The SObject API name
   */
  @AuraEnabled
  public static void deleteFieldConfig(String objectType) {
    if (!Schema.SObjectType.Duplicate_Viewer_Config__c.isDeletable()) {
      AuraHandledException ex = new AuraHandledException(
        'Insufficient permissions to delete configuration.'
      );
      ex.setMessage('Insufficient permissions to delete configuration.');
      throw ex;
    }

    if (String.isBlank(objectType)) {
      AuraHandledException e = new AuraHandledException(
        'Object type is required.'
      );
      e.setMessage('Object type is required.');
      throw e;
    }

    try {
      List<Duplicate_Viewer_Config__c> toDelete = [
        SELECT Id
        FROM Duplicate_Viewer_Config__c
        WHERE Object_Type__c = :objectType
      ];

      if (!toDelete.isEmpty()) {
        delete toDelete;
      }
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error deleting field configuration: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Checks if a field is a system/internal field that shouldn't be shown.
   */
  private static Boolean isSystemField(
    String fieldName,
    Schema.DescribeFieldResult fieldDescribe
  ) {
    // Skip standard system fields that aren't useful for preview/filter
    Set<String> systemFields = new Set<String>{
      'id',
      'isdeleted',
      'createdbyid',
      'createddate',
      'lastmodifiedbyid',
      'lastmodifieddate',
      'systemmodstamp',
      'lastactivitydate',
      'lastvieweddate',
      'lastreferenceddate',
      'ownerid',
      'masterrecordid',
      'jabornotifydisabled__c'
    };

    return systemFields.contains(fieldName.toLowerCase()) ||
      fieldDescribe.isCalculated() && !fieldDescribe.isFilterable();
  }

  // =====================================================================
  // WRAPPER CLASSES
  // =====================================================================

  public class FieldInfo implements Comparable {
    @AuraEnabled
    public String apiName;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String fieldType;
    @AuraEnabled
    public Boolean isFilterable;

    public Integer compareTo(Object compareTo) {
      FieldInfo other = (FieldInfo) compareTo;
      return this.label.compareTo(other.label);
    }
  }

  public class FieldConfigWrapper {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String objectType;
    @AuraEnabled
    public String fieldApiName;
    @AuraEnabled
    public Integer sortOrder;
    @AuraEnabled
    public Boolean showInPreview;
    @AuraEnabled
    public Boolean showAsFilter;
  }

  public class FieldConfigInput {
    public String id;
    public String fieldApiName;
    public Decimal sortOrder;
    public Boolean showInPreview;
    public Boolean showAsFilter;
  }
}
