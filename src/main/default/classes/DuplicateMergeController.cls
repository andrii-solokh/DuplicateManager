/**
 * @description Controller for duplicate record merge functionality.
 *              Provides methods to compare records side-by-side and merge them.
 * @author Andrii Solokh
 * @since 2026
 * @group Duplicate Management
 */
public with sharing class DuplicateMergeController {
    
    /**
     * @description Gets field comparison data for records in a duplicate set.
     *              Returns all fields with their values across all records, categorized
     *              by whether they differ, are the same, or are empty.
     * @param duplicateSetId The ID of the DuplicateRecordSet
     * @return ComparisonResult with field data organized for UI display
     */
    @AuraEnabled
    public static ComparisonResult getRecordComparison(Id duplicateSetId) {
        try {
            ComparisonResult result = new ComparisonResult();
            result.fields = new List<FieldComparison>();
            result.records = new List<RecordInfo>();
            
            // Get the duplicate record items
            List<DuplicateRecordItem> items = [
                SELECT Id, RecordId 
                FROM DuplicateRecordItem 
                WHERE DuplicateRecordSetId = :duplicateSetId
                ORDER BY CreatedDate ASC
            ];
            
            if (items.isEmpty()) {
                return result;
            }
            
            // Get object type from first record
            Id firstRecordId = items[0].RecordId;
            String objectType = firstRecordId.getSObjectType().getDescribe().getName();
            result.objectType = objectType;
            
            // Collect all record IDs
            List<Id> recordIds = new List<Id>();
            for (DuplicateRecordItem item : items) {
                recordIds.add(item.RecordId);
            }
            
            // Get all accessible fields for the object
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
                .get(objectType).getDescribe().fields.getMap();
            
            // Build list of queryable fields
            List<String> queryFields = new List<String>();
            Map<String, FieldMetadata> fieldMetadataMap = new Map<String, FieldMetadata>();
            
            for (String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                
                // Skip non-accessible, formula, and auto-number fields for merge
                if (!fieldDescribe.isAccessible()) {
                    continue;
                }
                
                // Skip certain system fields
                if (isSystemField(fieldName)) {
                    continue;
                }
                
                String fieldType = String.valueOf(fieldDescribe.getType());
                
                // Skip compound fields (Address, Location, etc.) - we show individual components instead
                if (isCompoundFieldType(fieldType)) {
                    continue;
                }
                queryFields.add(fieldName);
                
                FieldMetadata fm = new FieldMetadata();
                fm.apiName = fieldName;
                fm.label = fieldDescribe.getLabel();
                fm.type = fieldType;
                fm.isUpdateable = fieldDescribe.isUpdateable();
                fm.isRequired = !fieldDescribe.isNillable() && fieldDescribe.isCreateable();
                fm.isNameField = fieldDescribe.isNameField();
                fm.isCompoundComponent = isCompoundComponentField(fieldName, fieldDescribe);
                fieldMetadataMap.put(fieldName, fm);
            }
            
            // Query all records with all fields
            String query = 'SELECT ' + String.join(queryFields, ', ') + 
                          ' FROM ' + String.escapeSingleQuotes(objectType) + 
                          ' WHERE Id IN :recordIds';
            
            List<SObject> records = Database.query(query);
            
            // Build record info list
            for (SObject record : records) {
                RecordInfo ri = new RecordInfo();
                ri.recordId = record.Id;
                ri.recordName = getRecordName(record);
                result.records.add(ri);
            }
            
            // Compare each field across all records
            for (String fieldName : queryFields) {
                FieldMetadata fm = fieldMetadataMap.get(fieldName);
                if (fm == null) continue;
                
                FieldComparison fc = new FieldComparison();
                fc.apiName = fm.apiName;
                fc.label = fm.label;
                fc.type = fm.type;
                fc.isUpdateable = fm.isUpdateable;
                fc.isRequired = fm.isRequired;
                fc.isNameField = fm.isNameField;
                fc.values = new List<FieldValue>();
                
                Set<String> uniqueValues = new Set<String>();
                Boolean hasNonEmptyValue = false;
                
                for (SObject record : records) {
                    Object fieldValue = record.get(fieldName);
                    String displayValue = formatFieldValue(fieldValue, fm.type);
                    
                    FieldValue fv = new FieldValue();
                    fv.recordId = record.Id;
                    fv.value = fieldValue;
                    fv.displayValue = displayValue;
                    fv.isEmpty = fieldValue == null || String.valueOf(fieldValue).trim() == '';
                    fc.values.add(fv);
                    
                    if (!fv.isEmpty) {
                        hasNonEmptyValue = true;
                        uniqueValues.add(displayValue);
                    }
                }
                
                // Determine field status
                fc.allEmpty = !hasNonEmptyValue;
                fc.allSame = uniqueValues.size() <= 1;
                fc.hasDifference = uniqueValues.size() > 1;
                
                result.fields.add(fc);
            }
            
            // Sort fields: differences first, then same values, then empty
            result.fields.sort();
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error comparing records: ' + e.getMessage());
        }
    }
    
    /**
     * @description Merges duplicate records into a master record.
     *              Uses Database.merge for standard objects, or custom logic for others.
     * @param masterRecordId The ID of the record to keep as master
     * @param duplicateRecordIds List of record IDs to merge into master
     * @param fieldSelections Map of field API name to the record ID to use for that field's value
     * @param duplicateSetId The DuplicateRecordSet to delete after merge
     * @return MergeResult with success/failure info
     */
    @AuraEnabled
    public static MergeResult mergeRecords(
        Id masterRecordId, 
        List<Id> duplicateRecordIds,
        Map<String, Id> fieldSelections,
        Id duplicateSetId
    ) {
        Savepoint sp = Database.setSavepoint();
        
        try {
            MergeResult result = new MergeResult();
            result.success = false;
            
            if (masterRecordId == null || duplicateRecordIds == null || duplicateRecordIds.isEmpty()) {
                throw new AuraHandledException('Master record and at least one duplicate record are required.');
            }
            
            // Get object type
            String objectType = masterRecordId.getSObjectType().getDescribe().getName();
            
            // Check if this is a mergeable standard object
            Boolean isMergeableObject = isMergeableStandardObject(objectType);
            
            // Get all record IDs including master
            Set<Id> allRecordIds = new Set<Id>(duplicateRecordIds);
            allRecordIds.add(masterRecordId);
            
            // Query all records
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
                .get(objectType).getDescribe().fields.getMap();
            
            List<String> updateableFields = new List<String>();
            for (String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult fd = fieldMap.get(fieldName).getDescribe();
                if (fd.isUpdateable() && fd.isAccessible()) {
                    updateableFields.add(fieldName);
                }
            }
            
            String query = 'SELECT Id, ' + String.join(updateableFields, ', ') + 
                          ' FROM ' + String.escapeSingleQuotes(objectType) + 
                          ' WHERE Id IN :allRecordIds';
            
            Map<Id, SObject> recordsMap = new Map<Id, SObject>(Database.query(query));
            SObject masterRecord = recordsMap.get(masterRecordId);
            
            // Apply field selections to master record
            if (fieldSelections != null && !fieldSelections.isEmpty()) {
                for (String fieldName : fieldSelections.keySet()) {
                    Id sourceRecordId = fieldSelections.get(fieldName);
                    if (sourceRecordId != null && sourceRecordId != masterRecordId) {
                        SObject sourceRecord = recordsMap.get(sourceRecordId);
                        if (sourceRecord != null) {
                            try {
                                Object value = sourceRecord.get(fieldName);
                                masterRecord.put(fieldName, value);
                            } catch (Exception e) {
                                System.debug('Could not copy field ' + fieldName + ': ' + e.getMessage());
                            }
                        }
                    }
                }
                
                // Update master record with selected values
                update masterRecord;
            }
            
            // Perform the merge
            if (isMergeableObject) {
                // Use Database.merge for standard mergeable objects
                List<SObject> duplicatesToMerge = new List<SObject>();
                for (Id dupId : duplicateRecordIds) {
                    if (recordsMap.containsKey(dupId)) {
                        duplicatesToMerge.add(recordsMap.get(dupId));
                    }
                }
                
                // Database.merge can only merge up to 2 duplicates at a time
                for (SObject dupRecord : duplicatesToMerge) {
                    Database.MergeResult mergeResult = Database.merge(masterRecord, dupRecord, false);
                    if (!mergeResult.isSuccess()) {
                        String errorMsg = '';
                        for (Database.Error err : mergeResult.getErrors()) {
                            errorMsg += err.getMessage() + '; ';
                        }
                        throw new AuraHandledException('Merge failed: ' + errorMsg);
                    }
                }
            } else {
                // For non-mergeable objects, reparent related records and delete duplicates
                reparentRelatedRecords(objectType, masterRecordId, duplicateRecordIds);
                
                // Delete duplicate records
                List<SObject> recordsToDelete = new List<SObject>();
                for (Id dupId : duplicateRecordIds) {
                    SObject obj = Schema.getGlobalDescribe().get(objectType).newSObject();
                    obj.put('Id', dupId);
                    recordsToDelete.add(obj);
                }
                delete recordsToDelete;
            }
            
            // Delete the DuplicateRecordSet
            if (duplicateSetId != null) {
                try {
                    delete new DuplicateRecordSet(Id = duplicateSetId);
                } catch (Exception e) {
                    System.debug('Could not delete DuplicateRecordSet: ' + e.getMessage());
                }
            }
            
            result.success = true;
            result.masterRecordId = masterRecordId;
            result.mergedCount = duplicateRecordIds.size();
            result.message = 'Successfully merged ' + duplicateRecordIds.size() + ' record(s) into master.';
            
            return result;
            
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Error merging records: ' + e.getMessage());
        }
    }
    
    // =========================================================================
    // PRIVATE HELPER METHODS
    // =========================================================================
    
    private static Boolean isSystemField(String fieldName) {
        Set<String> systemFields = new Set<String>{
            'id', 'isdeleted', 'createddate', 'createdbyid', 'lastmodifieddate',
            'lastmodifiedbyid', 'systemmodstamp', 'lastactivitydate', 'lastvieweddate',
            'lastreferenceddate', 'masterrecordid', 'photourl', 'jaborid', 'jigsawcontactid'
        };
        return systemFields.contains(fieldName.toLowerCase());
    }
    
    /**
     * @description Checks if a field type is a compound field type that should be skipped.
     *              We show individual component fields instead (Street, City, Latitude, etc.)
     *              This handles all known Salesforce compound field types.
     * @param fieldType The field type string from Schema.DisplayType
     * @return True if this is a compound field type
     */
    private static Boolean isCompoundFieldType(String fieldType) {
        // Known Salesforce compound field types
        // ADDRESS - Standard and custom address compound fields
        // LOCATION - Geolocation compound fields
        // Add any future compound types here
        Set<String> compoundTypes = new Set<String>{ 
            'ADDRESS', 
            'LOCATION'
        };
        return compoundTypes.contains(fieldType.toUpperCase());
    }
    
    /**
     * @description Checks if a field is a component of a compound field (Address, Location, etc.)
     * @param fieldName The API name of the field
     * @param fieldDescribe The field describe result
     * @return True if this is a component of a compound field
     */
    private static Boolean isCompoundComponentField(String fieldName, Schema.DescribeFieldResult fieldDescribe) {
        // Check if this field belongs to a compound field using Salesforce's built-in method
        String compoundFieldName = fieldDescribe.getCompoundFieldName();
        if (String.isNotBlank(compoundFieldName)) {
            return true;
        }
        
        // Fallback: check common naming patterns for compound field components
        String lowerName = fieldName.toLowerCase();
        Set<String> compoundSuffixes = new Set<String>{
            // Address components
            'street', 'city', 'state', 'statecode', 'postalcode', 'country', 'countrycode',
            'geocodeaccuracy',
            // Location/Geolocation components  
            'latitude', 'longitude'
        };
        
        for (String suffix : compoundSuffixes) {
            if (lowerName.endsWith(suffix)) {
                return true;
            }
        }
        
        // Check for custom geolocation field components (__Latitude__s, __Longitude__s)
        if (lowerName.endsWith('__latitude__s') || lowerName.endsWith('__longitude__s')) {
            return true;
        }
        
        return false;
    }
    
    private static String getRecordName(SObject record) {
        try {
            Object nameValue = record.get('Name');
            if (nameValue != null) {
                return String.valueOf(nameValue);
            }
        } catch (Exception e) {
            // Try common name fields
            try {
                Object firstName = record.get('FirstName');
                Object lastName = record.get('LastName');
                if (lastName != null) {
                    return (firstName != null ? firstName + ' ' : '') + lastName;
                }
            } catch (Exception ex) {
                // Ignore
            }
        }
        return String.valueOf(record.get('Id'));
    }
    
    @TestVisible
    private static String formatFieldValue(Object value, String fieldType) {
        if (value == null) {
            return '';
        }
        
        if (fieldType == 'DATETIME') {
            return ((Datetime)value).format();
        } else if (fieldType == 'DATE') {
            return ((Date)value).format();
        } else if (fieldType == 'BOOLEAN') {
            return (Boolean)value ? 'Yes' : 'No';
        } else if (fieldType == 'CURRENCY' || fieldType == 'DOUBLE' || fieldType == 'PERCENT') {
            return String.valueOf(value);
        } else if (fieldType == 'ADDRESS') {
            return formatAddress(value);
        } else if (fieldType == 'LOCATION') {
            return formatLocation(value);
        }
        
        return String.valueOf(value);
    }
    
    /**
     * @description Formats an Address compound field into a readable string.
     * @param value The Address object
     * @return Formatted address string
     */
    @TestVisible
    private static String formatAddress(Object value) {
        if (value == null) {
            return '';
        }
        
        try {
            // Cast to Address type
            Address addr = (Address)value;
            List<String> parts = new List<String>();
            
            if (String.isNotBlank(addr.getStreet())) {
                parts.add(addr.getStreet());
            }
            if (String.isNotBlank(addr.getCity())) {
                parts.add(addr.getCity());
            }
            if (String.isNotBlank(addr.getState())) {
                parts.add(addr.getState());
            } else if (String.isNotBlank(addr.getStateCode())) {
                parts.add(addr.getStateCode());
            }
            if (String.isNotBlank(addr.getPostalCode())) {
                parts.add(addr.getPostalCode());
            }
            if (String.isNotBlank(addr.getCountry())) {
                parts.add(addr.getCountry());
            } else if (String.isNotBlank(addr.getCountryCode())) {
                parts.add(addr.getCountryCode());
            }
            
            if (parts.isEmpty()) {
                return '';
            }
            
            return String.join(parts, ', ');
        } catch (Exception e) {
            return String.valueOf(value);
        }
    }
    
    /**
     * @description Formats a Location (Geolocation) compound field into a readable string.
     * @param value The Location object
     * @return Formatted location string with latitude and longitude
     */
    @TestVisible
    private static String formatLocation(Object value) {
        if (value == null) {
            return '';
        }
        
        try {
            // Cast to Location type
            Location loc = (Location)value;
            Double lat = loc.getLatitude();
            Double lng = loc.getLongitude();
            
            if (lat == null && lng == null) {
                return '';
            }
            
            String latStr = lat != null ? String.valueOf(lat) : '—';
            String lngStr = lng != null ? String.valueOf(lng) : '—';
            
            return 'Lat: ' + latStr + ', Lng: ' + lngStr;
        } catch (Exception e) {
            return String.valueOf(value);
        }
    }
    
    private static Boolean isMergeableStandardObject(String objectType) {
        Set<String> mergeableObjects = new Set<String>{
            'Account', 'Contact', 'Lead', 'Case'
        };
        return mergeableObjects.contains(objectType);
    }
    
    private static void reparentRelatedRecords(String objectType, Id masterRecordId, List<Id> duplicateRecordIds) {
        // Get child relationships
        Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectType).getDescribe();
        List<Schema.ChildRelationship> childRelationships = objDescribe.getChildRelationships();
        
        for (Schema.ChildRelationship childRel : childRelationships) {
            Schema.SObjectField lookupField = childRel.getField();
            if (lookupField == null) continue;
            
            Schema.DescribeFieldResult fieldDescribe = lookupField.getDescribe();
            if (!fieldDescribe.isUpdateable()) continue;
            
            String childObjectName = childRel.getChildSObject().getDescribe().getName();
            String lookupFieldName = fieldDescribe.getName();
            
            try {
                // Query child records that reference the duplicate records
                String childQuery = 'SELECT Id, ' + lookupFieldName + 
                                   ' FROM ' + childObjectName + 
                                   ' WHERE ' + lookupFieldName + ' IN :duplicateRecordIds';
                
                List<SObject> childRecords = Database.query(childQuery);
                
                if (!childRecords.isEmpty()) {
                    // Reparent to master
                    for (SObject childRecord : childRecords) {
                        childRecord.put(lookupFieldName, masterRecordId);
                    }
                    update childRecords;
                }
            } catch (Exception e) {
                System.debug('Could not reparent ' + childObjectName + ': ' + e.getMessage());
            }
        }
    }
    
    // =========================================================================
    // WRAPPER CLASSES
    // =========================================================================
    
    public class ComparisonResult {
        @AuraEnabled public String objectType;
        @AuraEnabled public List<RecordInfo> records;
        @AuraEnabled public List<FieldComparison> fields;
    }
    
    public class RecordInfo {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String recordName;
    }
    
    public class FieldMetadata {
        public String apiName;
        public String label;
        public String type;
        public Boolean isUpdateable;
        public Boolean isRequired;
        public Boolean isNameField;
        public Boolean isCompoundComponent; // True if this field is part of a compound field (Address, Location, etc.)
    }
    
    public class FieldComparison implements Comparable {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String type;
        @AuraEnabled public Boolean isUpdateable;
        @AuraEnabled public Boolean isRequired;
        @AuraEnabled public Boolean isNameField;
        @AuraEnabled public List<FieldValue> values;
        @AuraEnabled public Boolean allEmpty;
        @AuraEnabled public Boolean allSame;
        @AuraEnabled public Boolean hasDifference;
        
        // Sort: differences first, then same, then empty
        public Integer compareTo(Object other) {
            FieldComparison otherField = (FieldComparison)other;
            
            // Differences first
            if (this.hasDifference && !otherField.hasDifference) return -1;
            if (!this.hasDifference && otherField.hasDifference) return 1;
            
            // Then non-empty same values
            if (!this.allEmpty && otherField.allEmpty) return -1;
            if (this.allEmpty && !otherField.allEmpty) return 1;
            
            // Finally sort by label
            return this.label.compareTo(otherField.label);
        }
    }
    
    public class FieldValue {
        @AuraEnabled public Id recordId;
        @AuraEnabled public Object value;
        @AuraEnabled public String displayValue;
        @AuraEnabled public Boolean isEmpty;
    }
    
    public class MergeResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id masterRecordId;
        @AuraEnabled public Integer mergedCount;
        @AuraEnabled public String message;
    }
}

