/**
 * @description Controller for the Duplicate Viewer LWC component.
 *              Provides methods to query and manage duplicate record sets.
 * @author Andrii Solokh
 * @since 2026
 * @group Duplicate Management
 */
public with sharing class DuplicateViewerController {
  /**
   * @description Retrieves duplicate record sets with their associated items.
   *              NOT cacheable to ensure fresh data on refresh.
   * @param objectType Optional filter for specific object type (e.g., 'Contact', 'Account')
   * @param searchTerm Optional search term to filter by name or rule label
   * @param limitCount Maximum number of sets to return
   * @param offsetCount Offset for pagination
   * @return List of DuplicateSetWrapper containing set info and items
   */
  @AuraEnabled
  public static DuplicateDataResult getDuplicateSets(
    String objectType,
    String searchTerm,
    Integer limitCount,
    Integer offsetCount
  ) {
    try {
      DuplicateDataResult result = new DuplicateDataResult();

      // If searching, find matching record IDs first
      Set<Id> matchingSetIds = null;
      if (String.isNotBlank(searchTerm)) {
        matchingSetIds = findSetsWithMatchingRecords(searchTerm, objectType);
        if (matchingSetIds.isEmpty()) {
          result.totalCount = 0;
          result.duplicateSets = new List<DuplicateSetWrapper>();
          return result;
        }
      }

      // Build query for duplicate sets
      String query =
        'SELECT Id, Name, RecordCount, DuplicateRuleId, DuplicateRule.MasterLabel, ' +
        'DuplicateRule.SobjectType, CreatedDate, LastModifiedDate ' +
        'FROM DuplicateRecordSet ';

      List<String> whereClauses = new List<String>();

      // Exclude sets without records
      whereClauses.add('RecordCount > 0');

      if (String.isNotBlank(objectType) && objectType != 'All') {
        whereClauses.add('DuplicateRule.SobjectType = :objectType');
      }

      // Filter by matching set IDs if searching
      if (matchingSetIds != null) {
        whereClauses.add('Id IN :matchingSetIds');
      }

      if (!whereClauses.isEmpty()) {
        query += 'WHERE ' + String.join(whereClauses, ' AND ') + ' ';
      }

      query += 'ORDER BY CreatedDate DESC ';
      query += 'LIMIT :limitCount OFFSET :offsetCount';

      List<DuplicateRecordSet> sets = Database.query(query);

      // Get total count for pagination
      String countQuery = 'SELECT COUNT() FROM DuplicateRecordSet';
      if (!whereClauses.isEmpty()) {
        countQuery += ' WHERE ' + String.join(whereClauses, ' AND ');
      }
      result.totalCount = Database.countQuery(countQuery);

      // Build wrapper list with items
      List<DuplicateSetWrapper> wrappers = new List<DuplicateSetWrapper>();

      for (DuplicateRecordSet drs : sets) {
        DuplicateSetWrapper wrapper = new DuplicateSetWrapper();
        wrapper.id = drs.Id;
        wrapper.name = drs.Name;
        wrapper.recordCount = drs.RecordCount;
        wrapper.ruleName = drs.DuplicateRule?.MasterLabel;
        wrapper.objectType = drs.DuplicateRule?.SobjectType;
        wrapper.createdDate = drs.CreatedDate;
        wrapper.lastModifiedDate = drs.LastModifiedDate;
        wrapper.duplicateRuleId = drs.DuplicateRuleId;
        wrappers.add(wrapper);
      }

      result.duplicateSets = wrappers;
      return result;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error fetching duplicate sets: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Retrieves duplicate record sets with preview data.
   * @param objectType Optional filter for specific object type (e.g., 'Contact', 'Account')
   * @param searchTerm Optional search term to filter by name or rule label
   * @param limitCount Maximum number of sets to return
   * @param offsetCount Offset for pagination
   * @return DuplicateDataResult with set info and preview data
   */
  @AuraEnabled
  public static DuplicateDataResult getDuplicateSetPreviews(
    String objectType,
    String searchTerm,
    Integer limitCount,
    Integer offsetCount
  ) {
    try {
      // First get the basic duplicate sets data
      DuplicateDataResult result = getDuplicateSets(
        objectType,
        searchTerm,
        limitCount,
        offsetCount
      );

      if (result.duplicateSets == null || result.duplicateSets.isEmpty()) {
        return result;
      }

      // Map to cache field describes per object type
      Map<String, Schema.SObjectType> globalDescribeMap = Schema.getGlobalDescribe();
      Map<String, Map<String, Schema.SObjectField>> fieldMapsByObject = new Map<String, Map<String, Schema.SObjectField>>();

      // Enhance each set with preview data
      for (DuplicateSetWrapper wrapper : result.duplicateSets) {
        try {
          // Get preview field configuration from the duplicate rule
          List<String> previewFieldNames = getPreviewFieldsForRule(
            wrapper.duplicateRuleId,
            wrapper.objectType
          );

          if (previewFieldNames.isEmpty()) {
            continue;
          }

          wrapper.previewFields = previewFieldNames;

          // Get field labels
          if (!fieldMapsByObject.containsKey(wrapper.objectType)) {
            Schema.SObjectType sObjType = globalDescribeMap.get(
              wrapper.objectType
            );
            if (sObjType != null) {
              fieldMapsByObject.put(
                wrapper.objectType,
                sObjType.getDescribe().fields.getMap()
              );
            }
          }

          Map<String, Schema.SObjectField> fieldMap = fieldMapsByObject.get(
            wrapper.objectType
          );
          if (fieldMap != null) {
            wrapper.fieldLabels = new Map<String, String>();
            for (String fieldName : previewFieldNames) {
              Schema.SObjectField field = fieldMap.get(fieldName);
              if (field != null) {
                wrapper.fieldLabels.put(
                  fieldName,
                  field.getDescribe().getLabel()
                );
              }
            }
          }

          // Get sample records for this set
          wrapper.sampleRecords = getSampleRecordsForSet(
            wrapper.id,
            wrapper.objectType,
            previewFieldNames,
            2
          );

          // Calculate field differences across sample records
          wrapper.fieldDifferences = calculateFieldDifferences(
            wrapper.sampleRecords,
            previewFieldNames
          );
        } catch (Exception e) {
          // Log error but continue processing other sets
          System.debug(
            'Error getting preview data for set ' +
              wrapper.id +
              ': ' +
              e.getMessage()
          );
        }
      }

      return result;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error fetching duplicate set previews: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Gets the preview field names for a duplicate rule.
   *              Uses smart defaults based on object type.
   * @param ruleId The duplicate rule ID
   * @param objectType The object type
   * @return List of field API names
   */
  private static List<String> getPreviewFieldsForRule(
    Id ruleId,
    String objectType
  ) {
    // First, try to get fields from matching rules for this object
    List<String> matchingFields = getMatchingRuleFields(objectType);
    if (!matchingFields.isEmpty()) {
      return matchingFields;
    }

    // Fall back to defaults if no matching rule fields found
    return getDefaultPreviewFields(objectType);
  }

  /**
   * @description Gets fields from MatchingRuleItems for the given object type.
   *              These are the fields actually used to identify duplicates.
   * @param objectType The object type
   * @return List of field API names from matching rules
   */
  private static List<String> getMatchingRuleFields(String objectType) {
    Set<String> fields = new Set<String>();

    if (String.isBlank(objectType)) {
      return new List<String>();
    }

    try {
      // Query MatchingRuleItems for all matching rules of this object type
      List<MatchingRuleItem> items = [
        SELECT Field
        FROM MatchingRuleItem
        WHERE MatchingRule.SobjectType = :objectType
      ];

      for (MatchingRuleItem item : items) {
        if (String.isNotBlank(item.Field)) {
          fields.add(item.Field);
        }
      }
    } catch (Exception e) {
      // If query fails, return empty - caller will fall back to defaults
      System.debug(
        LoggingLevel.WARN,
        'Error querying MatchingRuleItem: ' + e.getMessage()
      );
    }

    return new List<String>(fields);
  }

  /**
   * @description Gets default preview fields based on object type.
   * @param objectType The object type
   * @return List of default field API names
   */
  private static List<String> getDefaultPreviewFields(String objectType) {
    List<String> fields = new List<String>();

    if (String.isBlank(objectType)) {
      return fields;
    }

    // Smart defaults based on object type
    switch on objectType {
      when 'Contact' {
        fields.addAll(new List<String>{ 'Email', 'Phone', 'Title' });
      }
      when 'Account' {
        fields.addAll(new List<String>{ 'Website', 'Industry', 'Phone' });
      }
      when 'Lead' {
        fields.addAll(new List<String>{ 'Email', 'Company', 'Phone' });
      }
      when else {
        // For custom objects, try to get first 2 custom fields
        try {
          Schema.SObjectType sObjType = Schema.getGlobalDescribe()
            .get(objectType);
          if (sObjType != null) {
            Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe()
              .fields.getMap();
            Integer count = 0;
            for (String fieldName : fieldMap.keySet()) {
              if (fieldName.endsWith('__c') && count < 2) {
                fields.add(fieldName);
                count++;
              }
            }
          }
        } catch (Exception e) {
          System.debug('Error getting custom fields: ' + e.getMessage());
        }
      }
    }

    return fields;
  }

  /**
   * @description Finds duplicate sets containing records that match the search term.
   * @param searchTerm The search term to match against record names
   * @param objectType Optional object type filter
   * @return Set of DuplicateRecordSet IDs that contain matching records
   */
  private static Set<Id> findSetsWithMatchingRecords(
    String searchTerm,
    String objectType
  ) {
    Set<Id> matchingSetIds = new Set<Id>();
    String searchPattern = '%' + String.escapeSingleQuotes(searchTerm) + '%';

    // Determine which object types to search
    List<String> objectsToSearch = new List<String>();
    if (String.isNotBlank(objectType) && objectType != 'All') {
      objectsToSearch.add(objectType);
    } else {
      // Search common objects
      objectsToSearch.addAll(
        new List<String>{ 'Account', 'Contact', 'Lead', 'Case' }
      );
    }

    // Find record IDs matching search term for each object type
    Set<Id> matchingRecordIds = new Set<Id>();
    for (String objType : objectsToSearch) {
      try {
        String recordQuery =
          'SELECT Id FROM ' +
          objType +
          ' WHERE Name LIKE :searchPattern LIMIT 1000';
        for (SObject record : Database.query(recordQuery)) {
          matchingRecordIds.add(record.Id);
        }
      } catch (Exception e) {
        // Object might not have Name field or not be queryable
        System.debug('Error searching ' + objType + ': ' + e.getMessage());
      }
    }

    if (matchingRecordIds.isEmpty()) {
      return matchingSetIds;
    }

    // Find DuplicateRecordItems that reference the matching records
    List<DuplicateRecordItem> items = [
      SELECT DuplicateRecordSetId
      FROM DuplicateRecordItem
      WHERE RecordId IN :matchingRecordIds
    ];

    for (DuplicateRecordItem item : items) {
      matchingSetIds.add(item.DuplicateRecordSetId);
    }

    return matchingSetIds;
  }

  /**
   * @description Gets sample records with preview field values for a duplicate set.
   * @param setId The duplicate set ID
   * @param objectType The object type
   * @param fieldNames The field names to retrieve
   * @param sampleSize Number of sample records to return
   * @return List of RecordPreview
   */
  private static List<RecordPreview> getSampleRecordsForSet(
    Id setId,
    String objectType,
    List<String> fieldNames,
    Integer sampleSize
  ) {
    List<RecordPreview> previews = new List<RecordPreview>();

    if (
      setId == null ||
      String.isBlank(objectType) ||
      fieldNames == null ||
      fieldNames.isEmpty()
    ) {
      return previews;
    }

    try {
      // Get sample duplicate record items
      List<DuplicateRecordItem> items = [
        SELECT Id, RecordId
        FROM DuplicateRecordItem
        WHERE DuplicateRecordSetId = :setId
        ORDER BY CreatedDate ASC
        LIMIT :sampleSize
      ];

      if (items.isEmpty()) {
        return previews;
      }

      // Build dynamic SOQL query for actual records
      Set<Id> recordIds = new Set<Id>();
      for (DuplicateRecordItem item : items) {
        recordIds.add(item.RecordId);
      }

      // Validate and filter accessible fields
      Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectType);
      if (sObjType == null) {
        return previews;
      }

      Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe()
        .fields.getMap();
      List<String> accessibleFields = new List<String>{ 'Id', 'Name' };

      for (String fieldName : fieldNames) {
        Schema.SObjectField field = fieldMap.get(fieldName);
        if (field != null && field.getDescribe().isAccessible()) {
          accessibleFields.add(fieldName);
        }
      }

      // Build and execute query
      String query =
        'SELECT ' +
        String.join(accessibleFields, ', ') +
        ' FROM ' +
        String.escapeSingleQuotes(objectType) +
        ' WHERE Id IN :recordIds';

      List<SObject> records = Database.query(query);

      // Build preview objects
      for (SObject record : records) {
        RecordPreview preview = new RecordPreview();
        preview.recordId = record.Id;
        preview.recordName = (String) record.get('Name');
        preview.fieldValues = new Map<String, Object>();

        for (String fieldName : fieldNames) {
          if (accessibleFields.contains(fieldName)) {
            Object value = record.get(fieldName);
            preview.fieldValues.put(fieldName, value);
          }
        }

        previews.add(preview);
      }
    } catch (Exception e) {
      System.debug('Error getting sample records: ' + e.getMessage());
    }

    return previews;
  }

  /**
   * @description Calculates which fields have different values across sample records.
   * @param sampleRecords List of RecordPreview to compare
   * @param fieldNames Fields to check for differences
   * @return Map of field name to boolean (true if values differ)
   */
  private static Map<String, Boolean> calculateFieldDifferences(
    List<RecordPreview> sampleRecords,
    List<String> fieldNames
  ) {
    Map<String, Boolean> differences = new Map<String, Boolean>();

    if (
      sampleRecords == null ||
      sampleRecords.size() < 2 ||
      fieldNames == null
    ) {
      // Not enough records to compare, mark all as non-different
      for (String fieldName : fieldNames) {
        differences.put(fieldName, false);
      }
      return differences;
    }

    // Compare field values across all sample records
    for (String fieldName : fieldNames) {
      Set<String> uniqueValues = new Set<String>();

      for (RecordPreview record : sampleRecords) {
        if (record.fieldValues != null) {
          Object value = record.fieldValues.get(fieldName);
          // Convert to string for comparison (handles null)
          String strValue = value == null ? '' : String.valueOf(value);
          uniqueValues.add(strValue);
        }
      }

      // Field has differences if there's more than one unique value
      differences.put(fieldName, uniqueValues.size() > 1);
    }

    return differences;
  }

  /**
   * @description Retrieves items (records) for a specific duplicate set.
   * @param duplicateSetId The ID of the DuplicateRecordSet
   * @return List of DuplicateItemWrapper with record details
   */
  @AuraEnabled
  public static List<DuplicateItemWrapper> getDuplicateItems(
    Id duplicateSetId
  ) {
    try {
      List<DuplicateItemWrapper> items = new List<DuplicateItemWrapper>();

      // Get the duplicate record items
      List<DuplicateRecordItem> recordItems = [
        SELECT Id, RecordId, CreatedDate
        FROM DuplicateRecordItem
        WHERE DuplicateRecordSetId = :duplicateSetId
        ORDER BY CreatedDate ASC
      ];

      if (recordItems.isEmpty()) {
        return items;
      }

      // Get the object type from the first record
      Id firstRecordId = recordItems[0].RecordId;
      String objectType = firstRecordId.getSObjectType()
        .getDescribe()
        .getName();

      // Collect all record IDs
      Set<Id> recordIds = new Set<Id>();
      for (DuplicateRecordItem item : recordItems) {
        recordIds.add(item.RecordId);
      }

      // Query the actual records with Name field
      String recordQuery =
        'SELECT Id, Name FROM ' +
        String.escapeSingleQuotes(objectType) +
        ' WHERE Id IN :recordIds';

      Map<Id, SObject> recordsMap = new Map<Id, SObject>();
      try {
        List<SObject> records = Database.query(recordQuery);
        recordsMap = new Map<Id, SObject>(records);
      } catch (Exception e) {
        // Object might not have Name field, handle gracefully
        System.debug('Could not query records: ' + e.getMessage());
      }

      // Build wrappers
      for (DuplicateRecordItem item : recordItems) {
        DuplicateItemWrapper wrapper = new DuplicateItemWrapper();
        wrapper.id = item.Id;
        wrapper.recordId = item.RecordId;
        wrapper.createdDate = item.CreatedDate;
        wrapper.objectType = objectType;

        if (recordsMap.containsKey(item.RecordId)) {
          SObject record = recordsMap.get(item.RecordId);
          wrapper.recordName = (String) record.get('Name');
          wrapper.recordUrl = '/' + item.RecordId;
        } else {
          wrapper.recordName = 'Record Deleted';
          wrapper.recordUrl = null;
        }

        items.add(wrapper);
      }

      return items;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error fetching duplicate items: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Gets available object types that have duplicate rules.
   * @return List of object type options for the filter dropdown
   */
  @AuraEnabled(cacheable=true)
  public static List<ObjectTypeOption> getObjectTypeOptions() {
    try {
      List<ObjectTypeOption> options = new List<ObjectTypeOption>();

      // Add "All" option
      ObjectTypeOption allOption = new ObjectTypeOption();
      allOption.label = 'All Objects';
      allOption.value = 'All';
      options.add(allOption);

      // Get distinct object types from duplicate rules
      List<DuplicateRule> rules = [
        SELECT SobjectType
        FROM DuplicateRule
        WHERE IsActive = TRUE
        ORDER BY SobjectType
      ];

      Set<String> addedTypes = new Set<String>();
      for (DuplicateRule rule : rules) {
        if (!addedTypes.contains(rule.SobjectType)) {
          ObjectTypeOption opt = new ObjectTypeOption();
          opt.label = rule.SobjectType;
          opt.value = rule.SobjectType;
          options.add(opt);
          addedTypes.add(rule.SobjectType);
        }
      }

      return options;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error fetching object types: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Deletes a duplicate record set and its items.
   * @param setId The ID of the DuplicateRecordSet to delete
   */
  @AuraEnabled
  public static void deleteDuplicateSet(Id setId) {
    try {
      delete new DuplicateRecordSet(Id = setId);
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error deleting duplicate set: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Runs the duplicate scanner job for a specific object type.
   * @param objectType The object type to scan
   * @return The job ID
   */
  @AuraEnabled
  public static String runDuplicateScan(String objectType) {
    try {
      Id jobId = DuplicateScannerJob.execute(objectType);
      return jobId;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error running duplicate scan: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Aborts a running duplicate scanner job and all chained jobs.
   * @param jobId The initial AsyncApexJob ID
   */
  @AuraEnabled
  public static void abortJob(String jobId) {
    try {
      if (String.isBlank(jobId)) {
        return;
      }

      // Get the initial job to find its start time
      List<AsyncApexJob> initialJobs = [
        SELECT Id, CreatedDate
        FROM AsyncApexJob
        WHERE Id = :jobId
        LIMIT 1
      ];

      if (initialJobs.isEmpty()) {
        return;
      }

      Datetime jobStartTime = initialJobs[0].CreatedDate;

      // Abort all DuplicateScannerJob jobs that started at or after the initial job
      List<AsyncApexJob> jobsToAbort = [
        SELECT Id
        FROM AsyncApexJob
        WHERE
          ApexClass.Name = 'DuplicateScannerJob'
          AND CreatedDate >= :jobStartTime
          AND Status IN ('Queued', 'Preparing', 'Processing', 'Holding')
      ];

      for (AsyncApexJob job : jobsToAbort) {
        System.abortJob(job.Id);
      }
    } catch (Exception e) {
      throw new AuraHandledException('Error aborting job: ' + e.getMessage());
    }
  }

  /**
   * @description Gets the status of a running or completed async job.
   * @param jobId The AsyncApexJob ID
   * @return JobStatusWrapper with job details
   */
  @AuraEnabled
  public static JobStatusWrapper getJobStatus(String jobId) {
    try {
      JobStatusWrapper wrapper = new JobStatusWrapper();

      if (String.isBlank(jobId)) {
        wrapper.status = 'Unknown';
        wrapper.isComplete = true;
        return wrapper;
      }

      List<AsyncApexJob> jobs = [
        SELECT
          Id,
          Status,
          JobItemsProcessed,
          TotalJobItems,
          NumberOfErrors,
          ExtendedStatus,
          CreatedDate,
          CompletedDate,
          ApexClass.Name
        FROM AsyncApexJob
        WHERE Id = :jobId
        LIMIT 1
      ];

      if (jobs.isEmpty()) {
        wrapper.status = 'Not Found';
        wrapper.isComplete = true;
        return wrapper;
      }

      AsyncApexJob job = jobs[0];
      wrapper.jobId = job.Id;
      wrapper.status = job.Status;
      wrapper.jobItemsProcessed = job.JobItemsProcessed;
      wrapper.totalJobItems = job.TotalJobItems;
      wrapper.numberOfErrors = job.NumberOfErrors;
      wrapper.extendedStatus = job.ExtendedStatus;
      wrapper.createdDate = job.CreatedDate;
      wrapper.completedDate = job.CompletedDate;
      wrapper.className = job.ApexClass?.Name;

      // Calculate progress percentage
      if (job.TotalJobItems != null && job.TotalJobItems > 0) {
        wrapper.progressPercent =
          (job.JobItemsProcessed * 100) / job.TotalJobItems;
        wrapper.isComplete =
          job.Status == 'Completed' ||
          job.Status == 'Failed' ||
          job.Status == 'Aborted';
        wrapper.isSuccess =
          job.Status == 'Completed' &&
          job.NumberOfErrors == 0;
      } else {
        // For Queueable jobs (chained approach), check entire chain status
        wrapper.progressPercent = calculateQueueableProgress(job);

        // Chain is complete only when no more jobs are queued/processing
        Boolean chainComplete = isChainComplete(job);
        wrapper.isComplete =
          chainComplete ||
          job.Status == 'Failed' ||
          job.Status == 'Aborted';
        wrapper.isSuccess =
          chainComplete &&
          job.Status != 'Failed' &&
          job.Status != 'Aborted';
      }

      return wrapper;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error fetching job status: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Checks if the entire chain of queueable jobs is complete.
   * @param initialJob The initial AsyncApexJob
   * @return True if no more jobs are queued/processing
   */
  private static Boolean isChainComplete(AsyncApexJob initialJob) {
    Integer inProgressJobs = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE
        ApexClass.Name = 'DuplicateScannerJob'
        AND CreatedDate >= :initialJob.CreatedDate
        AND Status IN ('Queued', 'Preparing', 'Processing', 'Holding')
    ];
    return inProgressJobs == 0;
  }

  /**
   * @description Calculates estimated progress for chained Queueable jobs.
   *              Uses fixed increments per completed job for smooth progression.
   * @param initialJob The initial AsyncApexJob
   * @return Estimated progress percentage (0-100)
   */
  private static Integer calculateQueueableProgress(AsyncApexJob initialJob) {
    // Count jobs still in progress (the chain is still running)
    Integer inProgressJobs = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE
        ApexClass.Name = 'DuplicateScannerJob'
        AND CreatedDate >= :initialJob.CreatedDate
        AND Status IN ('Queued', 'Preparing', 'Processing', 'Holding')
    ];

    // If no jobs in progress, chain is complete
    if (inProgressJobs == 0) {
      return 100;
    }

    // Count completed jobs in the chain
    Integer completedJobs = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE
        ApexClass.Name = 'DuplicateScannerJob'
        AND CreatedDate >= :initialJob.CreatedDate
        AND Status = 'Completed'
    ];

    // Use fixed increments for smoother progress display
    // Each completed job adds 12%, starting at 10%, capped at 90% until done
    Integer baseProgress = 10;
    Integer incrementPerJob = 12;
    Integer calculatedProgress =
      baseProgress + (completedJobs * incrementPerJob);

    // Cap at 90% while still running to leave room for completion
    return Math.min(calculatedProgress, 90);
  }

  /**
   * @description Gets all recent duplicate scanner jobs.
   * @return List of recent jobs
   */
  @AuraEnabled
  public static List<JobStatusWrapper> getRecentJobs() {
    try {
      List<JobStatusWrapper> wrappers = new List<JobStatusWrapper>();

      List<AsyncApexJob> jobs = [
        SELECT
          Id,
          Status,
          JobItemsProcessed,
          TotalJobItems,
          NumberOfErrors,
          ExtendedStatus,
          CreatedDate,
          CompletedDate,
          ApexClass.Name
        FROM AsyncApexJob
        WHERE ApexClass.Name = 'DuplicateScannerJob'
        ORDER BY CreatedDate DESC
        LIMIT 10
      ];

      for (AsyncApexJob job : jobs) {
        JobStatusWrapper wrapper = new JobStatusWrapper();
        wrapper.jobId = job.Id;
        wrapper.status = job.Status;
        wrapper.jobItemsProcessed = job.JobItemsProcessed;
        wrapper.totalJobItems = job.TotalJobItems;
        wrapper.numberOfErrors = job.NumberOfErrors;
        wrapper.extendedStatus = job.ExtendedStatus;
        wrapper.createdDate = job.CreatedDate;
        wrapper.completedDate = job.CompletedDate;
        wrapper.className = job.ApexClass?.Name;

        if (job.TotalJobItems != null && job.TotalJobItems > 0) {
          wrapper.progressPercent =
            (job.JobItemsProcessed * 100) / job.TotalJobItems;
          wrapper.isComplete =
            job.Status == 'Completed' ||
            job.Status == 'Failed' ||
            job.Status == 'Aborted';
          wrapper.isSuccess =
            job.Status == 'Completed' &&
            job.NumberOfErrors == 0;
        } else {
          // For Queueable jobs, use chain-aware progress calculation
          wrapper.progressPercent = calculateQueueableProgress(job);
          Boolean chainComplete = isChainComplete(job);
          wrapper.isComplete =
            chainComplete ||
            job.Status == 'Failed' ||
            job.Status == 'Aborted';
          wrapper.isSuccess =
            chainComplete &&
            job.Status != 'Failed' &&
            job.Status != 'Aborted';
        }

        wrappers.add(wrapper);
      }

      return wrappers;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error fetching recent jobs: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Gets summary statistics for duplicates. NOT cacheable for fresh data.
   * @return DuplicateSummary with counts and stats
   */
  @AuraEnabled
  public static DuplicateSummary getDuplicateSummary() {
    try {
      DuplicateSummary summary = new DuplicateSummary();

      // Total duplicate sets
      summary.totalSets = [SELECT COUNT() FROM DuplicateRecordSet];

      // Total duplicate items
      summary.totalItems = [SELECT COUNT() FROM DuplicateRecordItem];

      // Sets by object type
      List<AggregateResult> byObject = [
        SELECT DuplicateRule.SobjectType objType, COUNT(Id) cnt
        FROM DuplicateRecordSet
        GROUP BY DuplicateRule.SobjectType
        ORDER BY COUNT(Id) DESC
      ];

      summary.setsByObject = new List<ObjectCount>();
      for (AggregateResult ar : byObject) {
        ObjectCount oc = new ObjectCount();
        oc.objectType = (String) ar.get('objType');
        oc.count = (Integer) ar.get('cnt');
        summary.setsByObject.add(oc);
      }

      return summary;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error fetching summary: ' + e.getMessage()
      );
    }
  }

  // =====================================================================
  // WRAPPER CLASSES
  // =====================================================================

  public class DuplicateDataResult {
    @AuraEnabled
    public List<DuplicateSetWrapper> duplicateSets;
    @AuraEnabled
    public Integer totalCount;
  }

  public class DuplicateSetWrapper {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public Integer recordCount;
    @AuraEnabled
    public String ruleName;
    @AuraEnabled
    public String objectType;
    @AuraEnabled
    public Datetime createdDate;
    @AuraEnabled
    public Datetime lastModifiedDate;
    @AuraEnabled
    public Id duplicateRuleId;
    @AuraEnabled
    public List<RecordPreview> sampleRecords;
    @AuraEnabled
    public List<String> previewFields;
    @AuraEnabled
    public Map<String, String> fieldLabels;
    @AuraEnabled
    public Map<String, Boolean> fieldDifferences; // field -> true if values differ across records
  }

  public class DuplicateItemWrapper {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id recordId;
    @AuraEnabled
    public String recordName;
    @AuraEnabled
    public String recordUrl;
    @AuraEnabled
    public String objectType;
    @AuraEnabled
    public Datetime createdDate;
  }

  public class ObjectTypeOption {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String value;
  }

  public class DuplicateSummary {
    @AuraEnabled
    public Integer totalSets;
    @AuraEnabled
    public Integer totalItems;
    @AuraEnabled
    public List<ObjectCount> setsByObject;
  }

  public class ObjectCount {
    @AuraEnabled
    public String objectType;
    @AuraEnabled
    public Integer count;
  }

  public class JobStatusWrapper {
    @AuraEnabled
    public Id jobId;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Integer jobItemsProcessed;
    @AuraEnabled
    public Integer totalJobItems;
    @AuraEnabled
    public Integer numberOfErrors;
    @AuraEnabled
    public String extendedStatus;
    @AuraEnabled
    public Datetime createdDate;
    @AuraEnabled
    public Datetime completedDate;
    @AuraEnabled
    public String className;
    @AuraEnabled
    public Integer progressPercent;
    @AuraEnabled
    public Boolean isComplete;
    @AuraEnabled
    public Boolean isSuccess;
  }

  public class RecordPreview {
    @AuraEnabled
    public Id recordId;
    @AuraEnabled
    public String recordName;
    @AuraEnabled
    public Map<String, Object> fieldValues;
    @AuraEnabled
    public Map<String, List<String>> allValues; // field -> [value1, value2, ...] for diff display
  }

  // =====================================================================
  // SCHEDULING METHODS
  // =====================================================================

  private static final String SCHEDULE_JOB_PREFIX = 'DuplicateScannerJob_';

  /**
   * @description Gets the current schedule status for duplicate scanning jobs.
   * @return List of ScheduleInfo for each object type
   */
  @AuraEnabled
  public static List<ScheduleInfo> getScheduleStatus() {
    try {
      List<ScheduleInfo> schedules = new List<ScheduleInfo>();

      // Get all scheduled jobs for DuplicateScannerScheduler
      List<CronTrigger> cronJobs = [
        SELECT
          Id,
          CronJobDetail.Name,
          CronExpression,
          NextFireTime,
          PreviousFireTime,
          State,
          TimesTriggered
        FROM CronTrigger
        WHERE CronJobDetail.Name LIKE 'DuplicateScannerJob_%'
        ORDER BY CronJobDetail.Name
      ];

      for (CronTrigger ct : cronJobs) {
        ScheduleInfo info = new ScheduleInfo();
        info.jobId = ct.Id;
        info.jobName = ct.CronJobDetail.Name;
        info.objectType = ct.CronJobDetail.Name.replace(
          SCHEDULE_JOB_PREFIX,
          ''
        );
        info.cronExpression = ct.CronExpression;
        info.nextFireTime = ct.NextFireTime;
        info.previousFireTime = ct.PreviousFireTime;
        info.state = ct.State;
        info.isScheduled = ct.State != 'DELETED';
        info.scheduledTime = extractTimeFromCron(ct.CronExpression);
        schedules.add(info);
      }

      return schedules;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error fetching schedule status: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Schedules a daily duplicate scan for the specified object type.
   * @param objectType The object type to scan
   * @param hour The hour to run (0-23)
   * @param minute The minute to run (0-59)
   * @return ScheduleInfo with the new schedule details
   */
  @AuraEnabled
  public static ScheduleInfo scheduleJob(
    String objectType,
    Integer hour,
    Integer minute
  ) {
    try {
      if (String.isBlank(objectType) || objectType == 'All') {
        throw new AuraHandledException(
          'Please select a specific object type to schedule.'
        );
      }

      // First, unschedule any existing job for this object type
      unscheduleJobInternal(objectType);

      // Build cron expression for daily at specified time
      // Format: Seconds Minutes Hours Day_of_month Month Day_of_week Year
      String cronExp = String.format(
        '0 {0} {1} * * ?',
        new List<Object>{ minute, hour }
      );

      // Schedule the job
      String jobName = SCHEDULE_JOB_PREFIX + objectType;
      DuplicateScannerScheduler scheduler = new DuplicateScannerScheduler(
        objectType
      );
      String jobId = System.schedule(jobName, cronExp, scheduler);

      // Return schedule info
      ScheduleInfo info = new ScheduleInfo();
      info.jobId = jobId;
      info.jobName = jobName;
      info.objectType = objectType;
      info.cronExpression = cronExp;
      info.isScheduled = true;
      info.scheduledTime = String.format(
        '{0}:{1}',
        new List<Object>{
          String.valueOf(hour).leftPad(2, '0'),
          String.valueOf(minute).leftPad(2, '0')
        }
      );

      // Get next fire time
      CronTrigger ct = [SELECT NextFireTime FROM CronTrigger WHERE Id = :jobId];
      info.nextFireTime = ct.NextFireTime;

      return info;
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      throw new AuraHandledException('Error scheduling job: ' + e.getMessage());
    }
  }

  /**
   * @description Unschedules the duplicate scan job for the specified object type.
   * @param objectType The object type to unschedule
   */
  @AuraEnabled
  public static void unscheduleJob(String objectType) {
    try {
      unscheduleJobInternal(objectType);
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error unscheduling job: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Internal method to unschedule a job.
   */
  private static void unscheduleJobInternal(String objectType) {
    String jobName = SCHEDULE_JOB_PREFIX + objectType;

    List<CronTrigger> existingJobs = [
      SELECT Id
      FROM CronTrigger
      WHERE CronJobDetail.Name = :jobName
    ];

    for (CronTrigger ct : existingJobs) {
      System.abortJob(ct.Id);
    }
  }

  /**
   * @description Extracts time string from cron expression.
   * @param cronExp The cron expression
   * @return Time string in HH:MM format
   */
  private static String extractTimeFromCron(String cronExp) {
    if (String.isBlank(cronExp)) {
      return '';
    }

    try {
      // Cron format: Seconds Minutes Hours Day_of_month Month Day_of_week Year
      List<String> parts = cronExp.split(' ');
      if (parts.size() >= 3) {
        String minute = parts[1].leftPad(2, '0');
        String hour = parts[2].leftPad(2, '0');
        return hour + ':' + minute;
      }
    } catch (Exception e) {
      // Ignore parsing errors
    }

    return '';
  }

  /**
   * @description Wrapper for schedule information
   */
  public class ScheduleInfo {
    @AuraEnabled
    public String jobId;
    @AuraEnabled
    public String jobName;
    @AuraEnabled
    public String objectType;
    @AuraEnabled
    public String cronExpression;
    @AuraEnabled
    public Datetime nextFireTime;
    @AuraEnabled
    public Datetime previousFireTime;
    @AuraEnabled
    public String state;
    @AuraEnabled
    public Boolean isScheduled;
    @AuraEnabled
    public String scheduledTime; // HH:MM format
  }
}
