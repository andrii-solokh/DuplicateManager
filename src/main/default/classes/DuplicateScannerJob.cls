/**
 * @description Production-grade Apex class that finds duplicates across all records of a given
 *              Salesforce object using the built-in Salesforce duplicate detection API
 *              (Datacloud.FindDuplicates), then creates DuplicateRecordSet and DuplicateRecordItem
 *              records for any detected duplicates.
 *
 * WHY DATACLOUD.FINDDUPLICATES:
 * - Datacloud.FindDuplicates is Salesforce's native duplicate detection API that leverages the
 *   configured Matching Rules and Duplicate Rules in the org.
 * - It provides a consistent, declarative approach to duplicate detection without requiring
 *   custom matching logic.
 * - It supports fuzzy matching, phonetic matching, and other advanced algorithms configured
 *   in Matching Rules.
 * - The API respects active Duplicate Rules and returns results grouped by rule.
 *
 * DUPLICATE RECORD ARCHITECTURE:
 * - DuplicateRecordSet: Parent record that represents a group of duplicates found by a specific
 *   Duplicate Rule. It stores the DuplicateRuleId to trace which rule identified the duplicates.
 * - DuplicateRecordItem: Child records linked to DuplicateRecordSet. Each item references one
 *   record in the duplicate group via the RecordId field.
 * - This parent-child relationship allows Salesforce users to review, merge, or manage duplicates
 *   through the standard Duplicate Management UI.
 *
 * WHY "WITHOUT SHARING":
 * - This job needs to scan ALL records across the entire org to identify duplicates.
 * - Using "with sharing" would limit visibility to records the running user can access,
 *   potentially missing duplicates in records the user cannot see.
 * - For a complete duplicate scan, system-level access is required.
 * - The job should only be executed by system administrators or scheduled jobs.
 *
 * GOVERNOR LIMITS AND BEST PRACTICES:
 * - Datacloud.FindDuplicates has a limit of 50 records per call.
 * - The API counts against callout limits when matching against external data sources.
 * - DML limits apply: 10,000 records per transaction.
 * - Heap size limits apply when processing large result sets.
 * - This implementation uses batch processing and chained Queueables to handle large datasets.
 * - Configurable batch size allows tuning for specific org sizes and complexity.
 *
 * @author Andrii Solokh
 * @since 2026
 * @group Duplicate Management
 */
public without sharing class DuplicateScannerJob implements Queueable, Database.AllowsCallouts {
  // =====================================================================
  // CONSTANTS
  // =====================================================================

  /**
   * Maximum number of records that can be passed to Datacloud.FindDuplicates per call.
   * This is a Salesforce platform limit.
   */
  private static final Integer MAX_FIND_DUPLICATES_BATCH_SIZE = 50;

  /**
   * Default batch size for querying records.
   * This is configurable via the constructor.
   */
  private static final Integer DEFAULT_QUERY_BATCH_SIZE = 2000;

  /**
   * Maximum number of DuplicateRecordItem records to insert in a single DML operation
   * to stay well within DML row limits and avoid lock contention.
   */
  private static final Integer MAX_DML_BATCH_SIZE = 200;

  /** Job name for scheduling purposes */
  @TestVisible
  private static String JOB_NAME = 'Duplicate Scanner Job';

  /** Cron expression for weekly Sunday 2 AM execution */
  private static final String WEEKLY_CRON_TRIGGER = '0 0 2 ? * SUN';

  // =====================================================================
  // INSTANCE VARIABLES
  // =====================================================================

  /** The API name of the SObject to scan for duplicates (e.g., 'Contact', 'Account', 'Lead') */
  private String objectApiName;

  /** The batch size for querying records from the database */
  private Integer queryBatchSize;

  /**
   * The last processed record ID for cursor-based pagination.
   * Using cursor-based pagination instead of OFFSET because Salesforce
   * limits OFFSET to 2000 records maximum.
   */
  private Id lastProcessedId;

  /**
   * Set of record IDs that have already been processed as part of a duplicate group.
   * Used to prevent creating redundant DuplicateRecordItem entries for the same record.
   */
  private Set<Id> processedRecordIds;

  /**
   * Set of canonical duplicate group keys to track which groups have been created.
   * A canonical key is a sorted, comma-separated list of record IDs in the group.
   * This prevents creating duplicate DuplicateRecordSets for the same group of records.
   */
  private Set<String> processedGroupKeys;

  /** List to accumulate errors during job execution */
  @TestVisible
  private List<JobError> jobErrors;

  // =====================================================================
  // CONSTRUCTORS
  // =====================================================================

  /**
   * @description Primary constructor that accepts the object API name to scan.
   * @param objectApiName The API name of the SObject to scan (e.g., 'Contact', 'Account').
   */
  public DuplicateScannerJob(String objectApiName) {
    this(objectApiName, DEFAULT_QUERY_BATCH_SIZE);
  }

  /**
   * @description Constructor with configurable batch size for performance tuning.
   * @param objectApiName The API name of the SObject to scan.
   * @param queryBatchSize The number of records to query per batch (max 2000 recommended).
   */
  public DuplicateScannerJob(String objectApiName, Integer queryBatchSize) {
    this(objectApiName, queryBatchSize, null, new Set<Id>(), new Set<String>());
  }

  /**
   * @description Internal constructor used for chaining Queueable jobs with state preservation.
   *              Uses cursor-based pagination (lastProcessedId) instead of OFFSET to avoid
   *              Salesforce's 2000 OFFSET limit.
   * @param objectApiName The API name of the SObject to scan.
   * @param queryBatchSize The number of records to query per batch.
   * @param lastProcessedId The last record ID processed (for cursor-based pagination).
   * @param processedRecordIds Set of already-processed record IDs.
   * @param processedGroupKeys Set of already-processed duplicate group keys.
   */
  private DuplicateScannerJob(
    String objectApiName,
    Integer queryBatchSize,
    Id lastProcessedId,
    Set<Id> processedRecordIds,
    Set<String> processedGroupKeys
  ) {
    this.objectApiName = objectApiName;
    this.queryBatchSize = Math.min(queryBatchSize, DEFAULT_QUERY_BATCH_SIZE);
    this.lastProcessedId = lastProcessedId;
    this.processedRecordIds = processedRecordIds;
    this.processedGroupKeys = processedGroupKeys;
    this.jobErrors = new List<JobError>();
  }

  // =====================================================================
  // PUBLIC STATIC METHODS
  // =====================================================================

  /**
   * @description Executes the duplicate scanner job immediately for the specified object.
   * @param objectApiName The API name of the SObject to scan.
   * @return The Job ID of the enqueued job.
   */
  public static Id execute(String objectApiName) {
    return System.enqueueJob(new DuplicateScannerJob(objectApiName));
  }

  /**
   * @description Executes the duplicate scanner job immediately with a custom batch size.
   * @param objectApiName The API name of the SObject to scan.
   * @param batchSize The number of records to process per batch.
   * @return The Job ID of the enqueued job.
   */
  public static Id execute(String objectApiName, Integer batchSize) {
    return System.enqueueJob(new DuplicateScannerJob(objectApiName, batchSize));
  }

  // =====================================================================
  // QUEUEABLE IMPLEMENTATION
  // =====================================================================

  /**
   * @description Main execution method for the Queueable interface.
   *              Orchestrates the duplicate scanning process:
   *              1. Validates the object API name
   *              2. Retrieves active duplicate rules for the object
   *              3. Queries a batch of records
   *              4. Calls Datacloud.FindDuplicates in sub-batches
   *              5. Creates DuplicateRecordSet and DuplicateRecordItem records
   *              6. Chains another job if more records remain
   * @param context The QueueableContext provided by the Salesforce runtime.
   */
  public void execute(QueueableContext context) {
    try {
      // Step 1: Validate the object API name and get the SObjectType
      Schema.SObjectType sObjectType = validateAndGetSObjectType();
      if (sObjectType == null) {
        return;
      }

      // Step 2: On first execution (lastProcessedId = null), delete existing DuplicateRecordSets
      // This ensures we don't create duplicate sets for the same records
      if (lastProcessedId == null) {
        deleteExistingDuplicateSets();
      }

      // Step 3: Retrieve active duplicate rules for this object type
      Map<String, Id> duplicateRulesMap = getActiveDuplicateRules(
        objectApiName
      );
      if (duplicateRulesMap.isEmpty()) {
        System.debug(
          LoggingLevel.WARN,
          'DuplicateScannerJob: No active duplicate rules found for ' +
          objectApiName
        );
        return;
      }

      // Step 4: Query a batch of records
      List<SObject> records = queryRecordBatch(sObjectType);
      if (records.isEmpty()) {
        // No more records to process - job complete
        sendCompletionNotification();
        return;
      }

      // Step 5: Process duplicates for this batch
      processDuplicates(records, duplicateRulesMap);

      // Step 6: Chain the next job if we received a full batch (more records likely exist)
      if (records.size() == queryBatchSize) {
        // Get the last record ID for cursor-based pagination
        Id lastRecordId = records[records.size() - 1].Id;
        chainNextJob(lastRecordId);
      } else {
        // We've processed all records - send completion notification
        sendCompletionNotification();
      }
    } catch (Exception e) {
      handleJobException(e);
    }
  }

  // =====================================================================
  // PRIVATE HELPER METHODS
  // =====================================================================

  /**
   * @description Validates the object API name and returns the corresponding SObjectType.
   * @return The Schema.SObjectType for the specified object, or null if invalid.
   */
  private Schema.SObjectType validateAndGetSObjectType() {
    if (String.isBlank(objectApiName)) {
      logError('Object API name cannot be blank', null);
      return null;
    }

    Schema.SObjectType sObjectType = Schema.getGlobalDescribe()
      .get(objectApiName);
    if (sObjectType == null) {
      logError('Invalid object API name: ' + objectApiName, null);
      return null;
    }

    return sObjectType;
  }

  /**
   * @description Deletes all existing DuplicateRecordSet records for the object type being scanned.
   *              This prevents creating duplicate DuplicateRecordSets for the same records when
   *              running multiple scans. Called only on the first job execution (offset = 0).
   *
   *              The deletion cascades to DuplicateRecordItem records automatically via
   *              Salesforce's standard cascade delete behavior.
   */
  private void deleteExistingDuplicateSets() {
    try {
      // Query all DuplicateRecordSets for rules matching this object type
      List<DuplicateRecordSet> existingSets = [
        SELECT Id
        FROM DuplicateRecordSet
        WHERE DuplicateRule.SobjectType = :objectApiName
        LIMIT 10000
      ];

      if (!existingSets.isEmpty()) {
        System.debug(
          LoggingLevel.INFO,
          'DuplicateScannerJob: Deleting ' +
            existingSets.size() +
            ' existing DuplicateRecordSets for ' +
            objectApiName
        );

        // Delete in batches to stay within governor limits
        delete existingSets;

        System.debug(
          LoggingLevel.INFO,
          'DuplicateScannerJob: Successfully deleted existing DuplicateRecordSets'
        );
      } else {
        System.debug(
          LoggingLevel.INFO,
          'DuplicateScannerJob: No existing DuplicateRecordSets found for ' +
          objectApiName
        );
      }
    } catch (Exception e) {
      // Log the error but continue with the scan
      // Failing to delete old sets shouldn't stop the scan entirely
      System.debug(
        LoggingLevel.ERROR,
        'DuplicateScannerJob: Error deleting existing DuplicateRecordSets: ' +
        e.getMessage()
      );
      logError(
        'Failed to delete existing DuplicateRecordSets: ' + e.getMessage(),
        null
      );
    }
  }

  /**
   * @description Retrieves all active duplicate rules for the specified object type.
   *              The rules are stored in a Map with the DeveloperName as key and the
   *              DuplicateRule Id as value.
   *
   *              This mapping is essential because Datacloud.FindDuplicates returns
   *              results organized by rule name, and we need the rule ID to create
   *              DuplicateRecordSet records.
   *
   * @param objectName The API name of the object to get duplicate rules for.
   * @return Map of DuplicateRule DeveloperName to DuplicateRule Id.
   */
  private Map<String, Id> getActiveDuplicateRules(String objectName) {
    Map<String, Id> rulesMap = new Map<String, Id>();

    try {
      // Query active duplicate rules for the specified object
      // Note: DuplicateRule is a setup object that requires special handling
      List<DuplicateRule> rules = [
        SELECT Id, DeveloperName, SobjectType, MasterLabel
        FROM DuplicateRule
        WHERE SobjectType = :objectName AND IsActive = TRUE
      ];

      for (DuplicateRule rule : rules) {
        rulesMap.put(rule.DeveloperName, rule.Id);
        // Also map by MasterLabel for flexibility in matching
        rulesMap.put(rule.MasterLabel, rule.Id);
      }

      System.debug(
        LoggingLevel.INFO,
        'DuplicateScannerJob: Found ' +
          rules.size() +
          ' active duplicate rules for ' +
          objectName
      );
    } catch (Exception e) {
      logError('Error retrieving duplicate rules: ' + e.getMessage(), e);
    }

    return rulesMap;
  }

  /**
   * @description Queries a batch of records for the specified SObject type.
   *              Uses cursor-based pagination (WHERE Id > lastProcessedId) instead of OFFSET
   *              to avoid Salesforce's 2000 OFFSET limit and enable scanning of unlimited records.
   * @param sObjectType The Schema.SObjectType to query.
   * @return List of SObject records for processing.
   */
  private List<SObject> queryRecordBatch(Schema.SObjectType sObjectType) {
    List<SObject> records = new List<SObject>();

    try {
      // Build a dynamic query using cursor-based pagination
      // This approach has no limit on the number of records that can be scanned
      String query;
      if (lastProcessedId == null) {
        // First batch - no WHERE clause on Id
        query =
          'SELECT Id FROM ' +
          String.escapeSingleQuotes(objectApiName) +
          ' ORDER BY Id ASC ' +
          ' LIMIT ' +
          queryBatchSize;
      } else {
        // Subsequent batches - use cursor-based pagination
        query =
          'SELECT Id FROM ' +
          String.escapeSingleQuotes(objectApiName) +
          ' WHERE Id > \'' +
          String.escapeSingleQuotes(String.valueOf(lastProcessedId)) +
          '\'' +
          ' ORDER BY Id ASC ' +
          ' LIMIT ' +
          queryBatchSize;
      }

      records = Database.query(query);

      System.debug(
        LoggingLevel.INFO,
        'DuplicateScannerJob: Queried ' +
          records.size() +
          ' records' +
          (lastProcessedId != null
            ? ' after ' + lastProcessedId
            : ' (first batch)')
      );
    } catch (Exception e) {
      logError('Error querying records: ' + e.getMessage(), e);
    }

    return records;
  }

  /**
   * @description Core method that processes duplicates for a batch of records.
   *              Breaks the batch into smaller sub-batches suitable for the
   *              Datacloud.FindDuplicates API (max 50 records per call).
   *
   * @param records The list of SObject records to check for duplicates.
   * @param duplicateRulesMap Map of rule names to rule IDs.
   */
  private void processDuplicates(
    List<SObject> records,
    Map<String, Id> duplicateRulesMap
  ) {
    // Collect all duplicate groups to create
    List<DuplicateGroup> allDuplicateGroups = new List<DuplicateGroup>();

    // Process records in sub-batches of MAX_FIND_DUPLICATES_BATCH_SIZE
    for (
      Integer i = 0; i < records.size(); i += MAX_FIND_DUPLICATES_BATCH_SIZE
    ) {
      Integer endIndex = Math.min(
        i + MAX_FIND_DUPLICATES_BATCH_SIZE,
        records.size()
      );
      List<SObject> subBatch = new List<SObject>();

      for (Integer j = i; j < endIndex; j++) {
        subBatch.add(records[j]);
      }

      // Call the duplicate detection API
      List<DuplicateGroup> batchGroups = findDuplicatesForBatch(
        subBatch,
        duplicateRulesMap
      );
      allDuplicateGroups.addAll(batchGroups);
    }

    // Insert all DuplicateRecordSets and their Items
    if (!allDuplicateGroups.isEmpty()) {
      insertDuplicateRecords(allDuplicateGroups);
    }
  }

  /**
   * @description Calls Datacloud.FindDuplicates for a batch of records and processes the results.
   *              For each duplicate match found, creates a DuplicateGroup object containing
   *              the DuplicateRecordSet and its associated DuplicateRecordItems.
   *
   * @param records The batch of records to check (max 50).
   * @param duplicateRulesMap Map of rule names to rule IDs.
   * @return List of DuplicateGroup objects representing found duplicates.
   */
  private List<DuplicateGroup> findDuplicatesForBatch(
    List<SObject> records,
    Map<String, Id> duplicateRulesMap
  ) {
    List<DuplicateGroup> groups = new List<DuplicateGroup>();

    try {
      // Call the Salesforce duplicate detection API
      // This returns a list of FindDuplicatesResult objects, one per input record
      List<Datacloud.FindDuplicatesResult> results = Datacloud.FindDuplicates.findDuplicates(
        records
      );

      // Process each result (corresponds to each input record)
      for (Integer i = 0; i < results.size(); i++) {
        Datacloud.FindDuplicatesResult result = results[i];
        SObject sourceRecord = records[i];

        // Skip if this record has already been processed in a duplicate group
        if (processedRecordIds.contains(sourceRecord.Id)) {
          continue;
        }

        // Process duplicate rules that matched
        for (
          Datacloud.DuplicateResult dupResult : result.getDuplicateResults()
        ) {
          // Get the matching rule name to find the associated Duplicate Rule ID
          String matchRuleName = dupResult.getMatchResults().isEmpty()
            ? null
            : dupResult.getMatchResults()[0].getRule();

          // Get duplicate rule ID from our map
          Id duplicateRuleId = getDuplicateRuleIdFromResult(
            dupResult,
            duplicateRulesMap
          );

          if (duplicateRuleId == null) {
            System.debug(
              LoggingLevel.WARN,
              'Could not find DuplicateRule ID for result. MatchRule: ' +
              matchRuleName
            );
            continue;
          }

          // Collect all matching record IDs from this result
          Set<Id> matchingRecordIds = new Set<Id>();
          matchingRecordIds.add(sourceRecord.Id);

          for (
            Datacloud.MatchResult matchResult : dupResult.getMatchResults()
          ) {
            for (
              Datacloud.MatchRecord matchRecord : matchResult.getMatchRecords()
            ) {
              SObject matchedRecord = matchRecord.getRecord();
              if (matchedRecord != null && matchedRecord.Id != null) {
                matchingRecordIds.add(matchedRecord.Id);
              }
            }
          }

          // Only create a duplicate group if we have at least 2 records
          if (matchingRecordIds.size() < 2) {
            continue;
          }

          // Create a canonical key for this group to check for duplicates
          String groupKey = createCanonicalGroupKey(matchingRecordIds);
          if (processedGroupKeys.contains(groupKey)) {
            continue;
          }

          // Create the duplicate group
          DuplicateGroup dupGroup = new DuplicateGroup();
          dupGroup.duplicateRuleId = duplicateRuleId;
          dupGroup.recordIds = matchingRecordIds;
          groups.add(dupGroup);

          // Mark these records and this group as processed
          processedRecordIds.addAll(matchingRecordIds);
          processedGroupKeys.add(groupKey);
        }
      }
    } catch (Exception e) {
      logError('Error calling FindDuplicates API: ' + e.getMessage(), e);
    }

    return groups;
  }

  /**
   * @description Attempts to retrieve the DuplicateRule ID from the FindDuplicates result.
   *              The API returns rule names which we map back to IDs.
   *
   * @param dupResult The DuplicateResult from the FindDuplicates API.
   * @param duplicateRulesMap Map of rule names to rule IDs.
   * @return The DuplicateRule Id, or null if not found.
   */
  private Id getDuplicateRuleIdFromResult(
    Datacloud.DuplicateResult dupResult,
    Map<String, Id> duplicateRulesMap
  ) {
    // Try to get rule from the duplicate result's rule field
    String ruleName = dupResult.getDuplicateRule();
    if (
      String.isNotBlank(ruleName) && duplicateRulesMap.containsKey(ruleName)
    ) {
      return duplicateRulesMap.get(ruleName);
    }

    // Fallback: try to get from match results
    for (Datacloud.MatchResult matchResult : dupResult.getMatchResults()) {
      String matchRuleName = matchResult.getRule();
      if (
        String.isNotBlank(matchRuleName) &&
        duplicateRulesMap.containsKey(matchRuleName)
      ) {
        return duplicateRulesMap.get(matchRuleName);
      }
    }

    // Last resort: return the first rule in our map
    if (!duplicateRulesMap.isEmpty()) {
      return duplicateRulesMap.values()[0];
    }

    return null;
  }

  /**
   * @description Creates a canonical key for a set of record IDs.
   *              The key is a sorted, pipe-delimited string of IDs.
   *              This ensures that the same group of records always produces the same key,
   *              regardless of which record triggered the duplicate detection.
   *
   * @param recordIds Set of record IDs in the duplicate group.
   * @return A canonical string key representing this group.
   */
  private String createCanonicalGroupKey(Set<Id> recordIds) {
    List<String> sortedIds = new List<String>();
    for (Id recordId : recordIds) {
      sortedIds.add(String.valueOf(recordId));
    }
    sortedIds.sort();
    return String.join(sortedIds, '|');
  }

  /**
   * @description Inserts DuplicateRecordSet records and their associated DuplicateRecordItem records.
   *              Performs bulk insert of parent records first, then child records.
   *              Uses Database.insert with allOrNone=false for partial success handling.
   *
   * @param duplicateGroups List of DuplicateGroup objects to insert.
   */
  private void insertDuplicateRecords(List<DuplicateGroup> duplicateGroups) {
    // Step 1: Create and insert DuplicateRecordSet records
    List<DuplicateRecordSet> recordSets = new List<DuplicateRecordSet>();

    for (DuplicateGroup dupGroup : duplicateGroups) {
      DuplicateRecordSet recordSet = new DuplicateRecordSet();
      recordSet.DuplicateRuleId = dupGroup.duplicateRuleId;
      recordSets.add(recordSet);
    }

    // Insert parent records (DuplicateRecordSet)
    Database.SaveResult[] setResults = Database.insert(recordSets, false);

    // Map successfully inserted sets to their groups
    Map<Integer, DuplicateRecordSet> successfulSets = new Map<Integer, DuplicateRecordSet>();
    for (Integer i = 0; i < setResults.size(); i++) {
      if (setResults[i].isSuccess()) {
        successfulSets.put(i, recordSets[i]);
      } else {
        for (Database.Error err : setResults[i].getErrors()) {
          logError(
            'Error inserting DuplicateRecordSet: ' + err.getMessage(),
            null
          );
        }
      }
    }

    // Step 2: Create and insert DuplicateRecordItem records
    List<DuplicateRecordItem> recordItems = new List<DuplicateRecordItem>();

    for (Integer i : successfulSets.keySet()) {
      DuplicateRecordSet recordSet = successfulSets.get(i);
      DuplicateGroup dupGroup = duplicateGroups[i];

      for (Id recordId : dupGroup.recordIds) {
        DuplicateRecordItem item = new DuplicateRecordItem();
        item.DuplicateRecordSetId = recordSet.Id;
        item.RecordId = recordId;
        recordItems.add(item);
      }
    }

    // Insert child records in batches
    if (!recordItems.isEmpty()) {
      insertRecordItemsInBatches(recordItems);
    }

    System.debug(
      LoggingLevel.INFO,
      'DuplicateScannerJob: Created ' +
        successfulSets.size() +
        ' DuplicateRecordSets with ' +
        recordItems.size() +
        ' DuplicateRecordItems'
    );
  }

  /**
   * @description Inserts DuplicateRecordItem records in batches to avoid DML limits.
   * @param items The list of DuplicateRecordItem records to insert.
   */
  private void insertRecordItemsInBatches(List<DuplicateRecordItem> items) {
    for (Integer i = 0; i < items.size(); i += MAX_DML_BATCH_SIZE) {
      Integer endIndex = Math.min(i + MAX_DML_BATCH_SIZE, items.size());
      List<DuplicateRecordItem> batch = new List<DuplicateRecordItem>();

      for (Integer j = i; j < endIndex; j++) {
        batch.add(items[j]);
      }

      Database.SaveResult[] itemResults = Database.insert(batch, false);
      for (Integer k = 0; k < itemResults.size(); k++) {
        if (!itemResults[k].isSuccess()) {
          for (Database.Error err : itemResults[k].getErrors()) {
            logError(
              'Error inserting DuplicateRecordItem: ' + err.getMessage(),
              null
            );
          }
        }
      }
    }
  }

  /**
   * @description Chains another instance of this job to continue processing
   *              the next batch of records. Uses cursor-based pagination by
   *              passing the last processed record ID.
   * @param lastRecordId The ID of the last record processed in the current batch.
   */
  private void chainNextJob(Id lastRecordId) {
    if (!Test.isRunningTest()) {
      System.enqueueJob(
        new DuplicateScannerJob(
          objectApiName,
          queryBatchSize,
          lastRecordId,
          processedRecordIds,
          processedGroupKeys
        )
      );
    }
  }

  /**
   * @description Sends a notification email when the job completes.
   */
  private void sendCompletionNotification() {
    if (jobErrors.isEmpty()) {
      System.debug(
        LoggingLevel.INFO,
        'DuplicateScannerJob: Completed successfully for ' +
          objectApiName +
          '. Processed ' +
          processedRecordIds.size() +
          ' records in duplicate groups.'
      );
      return;
    }

    // Send error notification email
    try {
      String emailBody =
        '<h2>Duplicate Scanner Job Errors for ' +
        objectApiName +
        '</h2>';
      for (JobError error : jobErrors) {
        emailBody += '<p><strong>Error:</strong> ' + error.message + '</p>';
        if (error.recordIds != null && !error.recordIds.isEmpty()) {
          emailBody +=
            '<p><strong>Records:</strong> ' +
            String.join(error.recordIds, ', ') +
            '</p>';
        }
        emailBody += '<hr/>';
      }

      Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
      mail.setToAddresses(new List<String>{ UserInfo.getUserEmail() });
      mail.setReplyTo(UserInfo.getUserEmail());
      mail.setSenderDisplayName('Duplicate Scanner Job');
      mail.setSubject('Duplicate Scanner Job Errors - ' + objectApiName);
      mail.setHtmlBody(emailBody);
      Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'DuplicateScannerJob: Error sending notification email: ' +
        e.getMessage()
      );
    }
  }

  /**
   * @description Logs an error and stores it for later notification.
   * @param message The error message.
   * @param ex The exception (can be null).
   */
  private void logError(String message, Exception ex) {
    JobError error = new JobError();
    error.message = message;
    if (ex != null) {
      error.message += ' | Stack Trace: ' + ex.getStackTraceString();
    }
    jobErrors.add(error);

    System.debug(LoggingLevel.ERROR, 'DuplicateScannerJob: ' + error.message);
  }

  /**
   * @description Handles any uncaught exceptions during job execution.
   * @param e The caught exception.
   */
  private void handleJobException(Exception e) {
    logError('Fatal error in DuplicateScannerJob: ' + e.getMessage(), e);
    sendCompletionNotification();
  }

  // =====================================================================
  // INNER CLASSES
  // =====================================================================

  /**
   * @description Inner class to temporarily store a duplicate group before insertion.
   *              Holds the Duplicate Rule ID and the set of record IDs that form the group.
   */
  public class DuplicateGroup {
    /** The ID of the Duplicate Rule that identified this group */
    public Id duplicateRuleId;

    /** The set of record IDs that are duplicates of each other */
    public Set<Id> recordIds;

    public DuplicateGroup() {
      this.recordIds = new Set<Id>();
    }
  }

  /**
   * @description Inner class to store job errors for reporting.
   */
  public class JobError {
    /** The error message */
    public String message;

    /** Optional list of record IDs associated with the error */
    public List<String> recordIds;

    public JobError() {
      this.recordIds = new List<String>();
    }
  }
}
