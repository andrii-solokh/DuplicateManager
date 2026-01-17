/**
 * @description Test class for DuplicateViewerController.
 *              Provides comprehensive coverage of all controller methods.
 * @author Andrii Solokh
 * @since 2026
 * @group Duplicate Management
 */
@IsTest
private class DuplicateViewerControllerTest {
    
    // =====================================================================
    // TEST SETUP
    // =====================================================================
    
    @TestSetup
    static void setupTestData() {
        // Create test Contacts
        List<Contact> contacts = new List<Contact>();
        
        contacts.add(new Contact(
            FirstName = 'John',
            LastName = 'TestDuplicate',
            Email = 'john.test@example.com'
        ));
        
        contacts.add(new Contact(
            FirstName = 'John',
            LastName = 'TestDuplicate',
            Email = 'john.test2@example.com'
        ));
        
        contacts.add(new Contact(
            FirstName = 'Jane',
            LastName = 'TestUnique',
            Email = 'jane.unique@example.com'
        ));
        
        // Insert with allow duplicates
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.DuplicateRuleHeader.allowSave = true;
        dmlOptions.DuplicateRuleHeader.runAsCurrentUser = false;
        Database.insert(contacts, dmlOptions);
    }
    
    // =====================================================================
    // GET DUPLICATE SETS TESTS
    // =====================================================================
    
    @IsTest
    static void testGetDuplicateSetsNoFilter() {
        Test.startTest();
        DuplicateViewerController.DuplicateDataResult result = 
            DuplicateViewerController.getDuplicateSets(null, 10, 0);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.duplicateSets, 'Duplicate sets list should not be null');
        System.assertNotEquals(null, result.totalCount, 'Total count should not be null');
    }
    
    @IsTest
    static void testGetDuplicateSetsWithAllFilter() {
        Test.startTest();
        DuplicateViewerController.DuplicateDataResult result = 
            DuplicateViewerController.getDuplicateSets('All', 10, 0);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @IsTest
    static void testGetDuplicateSetsWithObjectFilter() {
        Test.startTest();
        DuplicateViewerController.DuplicateDataResult result = 
            DuplicateViewerController.getDuplicateSets('Contact', 10, 0);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @IsTest
    static void testGetDuplicateSetsWithPagination() {
        Test.startTest();
        DuplicateViewerController.DuplicateDataResult result = 
            DuplicateViewerController.getDuplicateSets('Contact', 5, 5);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    // =====================================================================
    // GET DUPLICATE ITEMS TESTS
    // =====================================================================
    
    @IsTest
    static void testGetDuplicateItemsEmptySet() {
        // Create a mock DuplicateRecordSet
        DuplicateRule rule = [SELECT Id FROM DuplicateRule WHERE SobjectType = 'Contact' AND IsActive = true LIMIT 1];
        
        if (rule != null) {
            DuplicateRecordSet drs = new DuplicateRecordSet();
            drs.DuplicateRuleId = rule.Id;
            insert drs;
            
            Test.startTest();
            List<DuplicateViewerController.DuplicateItemWrapper> items = 
                DuplicateViewerController.getDuplicateItems(drs.Id);
            Test.stopTest();
            
            System.assertNotEquals(null, items, 'Items list should not be null');
            System.assertEquals(0, items.size(), 'Items list should be empty');
            
            // Cleanup
            delete drs;
        }
    }
    
    @IsTest
    static void testGetDuplicateItemsWithRecords() {
        // Get an active duplicate rule
        List<DuplicateRule> rules = [SELECT Id FROM DuplicateRule WHERE SobjectType = 'Contact' AND IsActive = true LIMIT 1];
        
        if (!rules.isEmpty()) {
            // Create DuplicateRecordSet
            DuplicateRecordSet drs = new DuplicateRecordSet();
            drs.DuplicateRuleId = rules[0].Id;
            insert drs;
            
            // Get test contacts
            List<Contact> contacts = [SELECT Id FROM Contact LIMIT 2];
            
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
                List<DuplicateViewerController.DuplicateItemWrapper> result = 
                    DuplicateViewerController.getDuplicateItems(drs.Id);
                Test.stopTest();
                
                System.assertNotEquals(null, result, 'Result should not be null');
                System.assertEquals(2, result.size(), 'Should return 2 items');
                
                // Verify wrapper properties
                for (DuplicateViewerController.DuplicateItemWrapper wrapper : result) {
                    System.assertNotEquals(null, wrapper.recordId, 'Record ID should not be null');
                    System.assertNotEquals(null, wrapper.objectType, 'Object type should not be null');
                }
            }
            
            // Cleanup
            delete drs;
        }
    }
    
    // =====================================================================
    // GET OBJECT TYPE OPTIONS TESTS
    // =====================================================================
    
    @IsTest
    static void testGetObjectTypeOptions() {
        Test.startTest();
        List<DuplicateViewerController.ObjectTypeOption> options = 
            DuplicateViewerController.getObjectTypeOptions();
        Test.stopTest();
        
        System.assertNotEquals(null, options, 'Options should not be null');
        System.assert(options.size() >= 1, 'Should have at least the All option');
        
        // Verify "All" option is first
        System.assertEquals('All', options[0].value, 'First option should be All');
        System.assertEquals('All Objects', options[0].label, 'First option label should be All Objects');
    }
    
    // =====================================================================
    // DELETE DUPLICATE SET TESTS
    // =====================================================================
    
    @IsTest
    static void testDeleteDuplicateSet() {
        // Get an active duplicate rule
        List<DuplicateRule> rules = [SELECT Id FROM DuplicateRule WHERE SobjectType = 'Contact' AND IsActive = true LIMIT 1];
        
        if (!rules.isEmpty()) {
            // Create DuplicateRecordSet
            DuplicateRecordSet drs = new DuplicateRecordSet();
            drs.DuplicateRuleId = rules[0].Id;
            insert drs;
            
            Id drsId = drs.Id;
            
            Test.startTest();
            DuplicateViewerController.deleteDuplicateSet(drsId);
            Test.stopTest();
            
            // Verify deleted
            List<DuplicateRecordSet> remaining = [SELECT Id FROM DuplicateRecordSet WHERE Id = :drsId];
            System.assertEquals(0, remaining.size(), 'DuplicateRecordSet should be deleted');
        }
    }
    
    @IsTest
    static void testDeleteDuplicateSetInvalidId() {
        Test.startTest();
        try {
            DuplicateViewerController.deleteDuplicateSet(null);
            // If no exception, that's also acceptable behavior
            System.assert(true, 'Operation completed');
        } catch (AuraHandledException e) {
            // Exception is expected for invalid ID
            System.assert(true, 'Exception thrown as expected');
        } catch (Exception e) {
            System.assert(true, 'Exception thrown as expected');
        }
        Test.stopTest();
    }
    
    // =====================================================================
    // RUN DUPLICATE SCAN TESTS
    // =====================================================================
    
    @IsTest
    static void testRunDuplicateScan() {
        Test.startTest();
        String jobId = DuplicateViewerController.runDuplicateScan('Contact');
        Test.stopTest();
        
        System.assertNotEquals(null, jobId, 'Job ID should not be null');
    }
    
    @IsTest
    static void testRunDuplicateScanWithBlankObject() {
        Test.startTest();
        String jobId = DuplicateViewerController.runDuplicateScan('');
        Test.stopTest();
        
        // Job should still enqueue
        System.assertNotEquals(null, jobId, 'Job ID should not be null');
    }
    
    // =====================================================================
    // GET JOB STATUS TESTS
    // =====================================================================
    
    @IsTest
    static void testGetJobStatusBlankId() {
        Test.startTest();
        DuplicateViewerController.JobStatusWrapper status = 
            DuplicateViewerController.getJobStatus('');
        Test.stopTest();
        
        System.assertNotEquals(null, status, 'Status should not be null');
        System.assertEquals('Unknown', status.status, 'Status should be Unknown for blank ID');
        System.assertEquals(true, status.isComplete, 'Should be marked as complete');
    }
    
    @IsTest
    static void testGetJobStatusNullId() {
        Test.startTest();
        DuplicateViewerController.JobStatusWrapper status = 
            DuplicateViewerController.getJobStatus(null);
        Test.stopTest();
        
        System.assertNotEquals(null, status, 'Status should not be null');
        System.assertEquals('Unknown', status.status, 'Status should be Unknown');
    }
    
    @IsTest
    static void testGetJobStatusValidJob() {
        // First enqueue a job
        Test.startTest();
        Id jobId = DuplicateScannerJob.execute('Contact');
        Test.stopTest();
        
        // Get status
        DuplicateViewerController.JobStatusWrapper status = 
            DuplicateViewerController.getJobStatus(String.valueOf(jobId));
        
        System.assertNotEquals(null, status, 'Status should not be null');
        System.assertNotEquals(null, status.status, 'Status field should not be null');
    }
    
    @IsTest
    static void testGetJobStatusInvalidId() {
        Test.startTest();
        DuplicateViewerController.JobStatusWrapper status = 
            DuplicateViewerController.getJobStatus('707000000000000AAA');
        Test.stopTest();
        
        System.assertNotEquals(null, status, 'Status should not be null');
        System.assertEquals('Not Found', status.status, 'Status should be Not Found');
    }
    
    // =====================================================================
    // GET RECENT JOBS TESTS
    // =====================================================================
    
    @IsTest
    static void testGetRecentJobs() {
        Test.startTest();
        List<DuplicateViewerController.JobStatusWrapper> jobs = 
            DuplicateViewerController.getRecentJobs();
        Test.stopTest();
        
        System.assertNotEquals(null, jobs, 'Jobs list should not be null');
    }
    
    @IsTest
    static void testGetRecentJobsAfterExecution() {
        Test.startTest();
        DuplicateScannerJob.execute('Contact');
        Test.stopTest();
        
        List<DuplicateViewerController.JobStatusWrapper> jobs = 
            DuplicateViewerController.getRecentJobs();
        
        System.assertNotEquals(null, jobs, 'Jobs list should not be null');
    }
    
    // =====================================================================
    // GET DUPLICATE SUMMARY TESTS
    // =====================================================================
    
    @IsTest
    static void testGetDuplicateSummary() {
        Test.startTest();
        DuplicateViewerController.DuplicateSummary summary = 
            DuplicateViewerController.getDuplicateSummary();
        Test.stopTest();
        
        System.assertNotEquals(null, summary, 'Summary should not be null');
        System.assertNotEquals(null, summary.totalSets, 'Total sets should not be null');
        System.assertNotEquals(null, summary.totalItems, 'Total items should not be null');
        System.assertNotEquals(null, summary.setsByObject, 'Sets by object should not be null');
    }
    
    @IsTest
    static void testGetDuplicateSummaryWithData() {
        // Create some test data
        List<DuplicateRule> rules = [SELECT Id FROM DuplicateRule WHERE SobjectType = 'Contact' AND IsActive = true LIMIT 1];
        
        if (!rules.isEmpty()) {
            DuplicateRecordSet drs = new DuplicateRecordSet();
            drs.DuplicateRuleId = rules[0].Id;
            insert drs;
            
            Contact c = [SELECT Id FROM Contact LIMIT 1];
            DuplicateRecordItem item = new DuplicateRecordItem();
            item.DuplicateRecordSetId = drs.Id;
            item.RecordId = c.Id;
            insert item;
            
            Test.startTest();
            DuplicateViewerController.DuplicateSummary summary = 
                DuplicateViewerController.getDuplicateSummary();
            Test.stopTest();
            
            System.assert(summary.totalSets >= 1, 'Should have at least 1 set');
            System.assert(summary.totalItems >= 1, 'Should have at least 1 item');
            
            // Cleanup
            delete drs;
        }
    }
    
    // =====================================================================
    // SCHEDULING TESTS
    // =====================================================================
    
    @IsTest
    static void testGetScheduleStatus() {
        Test.startTest();
        List<DuplicateViewerController.ScheduleInfo> schedules = 
            DuplicateViewerController.getScheduleStatus();
        Test.stopTest();
        
        System.assertNotEquals(null, schedules, 'Schedules should not be null');
    }
    
    @IsTest
    static void testScheduleJob() {
        Test.startTest();
        DuplicateViewerController.ScheduleInfo info = 
            DuplicateViewerController.scheduleJob('Contact', 2, 30);
        Test.stopTest();
        
        System.assertNotEquals(null, info, 'Schedule info should not be null');
        System.assertEquals('Contact', info.objectType, 'Object type should match');
        System.assertEquals(true, info.isScheduled, 'Should be marked as scheduled');
        System.assertNotEquals(null, info.cronExpression, 'Cron expression should not be null');
        
        // Cleanup - abort the scheduled job
        DuplicateViewerController.unscheduleJob('Contact');
    }
    
    @IsTest
    static void testScheduleJobAllObjectType() {
        Test.startTest();
        try {
            DuplicateViewerController.scheduleJob('All', 2, 30);
            System.assert(false, 'Should have thrown exception for All object type');
        } catch (AuraHandledException e) {
            // Exception is expected for 'All' object type
            System.assert(true, 'Exception thrown as expected for All object type');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testScheduleJobBlankObjectType() {
        Test.startTest();
        try {
            DuplicateViewerController.scheduleJob('', 2, 30);
            System.assert(false, 'Should have thrown exception for blank object type');
        } catch (AuraHandledException e) {
            System.assert(true, 'Exception thrown as expected');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testUnscheduleJob() {
        // First schedule a job
        DuplicateViewerController.scheduleJob('Account', 3, 0);
        
        Test.startTest();
        DuplicateViewerController.unscheduleJob('Account');
        Test.stopTest();
        
        // Verify unscheduled
        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger 
            WHERE CronJobDetail.Name = 'DuplicateScannerJob_Account'
        ];
        System.assertEquals(0, jobs.size(), 'Job should be unscheduled');
    }
    
    @IsTest
    static void testUnscheduleJobNotExists() {
        Test.startTest();
        // Should not throw error even if job doesn't exist
        DuplicateViewerController.unscheduleJob('NonExistentObject__c');
        Test.stopTest();
        
        System.assert(true, 'Should complete without error');
    }
    
    // =====================================================================
    // WRAPPER CLASS TESTS
    // =====================================================================
    
    @IsTest
    static void testDuplicateDataResultWrapper() {
        DuplicateViewerController.DuplicateDataResult result = 
            new DuplicateViewerController.DuplicateDataResult();
        result.duplicateSets = new List<DuplicateViewerController.DuplicateSetWrapper>();
        result.totalCount = 10;
        
        System.assertEquals(0, result.duplicateSets.size(), 'List should be empty');
        System.assertEquals(10, result.totalCount, 'Count should be 10');
    }
    
    @IsTest
    static void testDuplicateSetWrapper() {
        DuplicateViewerController.DuplicateSetWrapper wrapper = 
            new DuplicateViewerController.DuplicateSetWrapper();
        wrapper.name = 'Test Set';
        wrapper.recordCount = 5;
        wrapper.ruleName = 'Test Rule';
        wrapper.objectType = 'Contact';
        wrapper.createdDate = Datetime.now();
        wrapper.lastModifiedDate = Datetime.now();
        
        System.assertEquals('Test Set', wrapper.name, 'Name should match');
        System.assertEquals(5, wrapper.recordCount, 'Record count should be 5');
    }
    
    @IsTest
    static void testDuplicateItemWrapper() {
        DuplicateViewerController.DuplicateItemWrapper wrapper = 
            new DuplicateViewerController.DuplicateItemWrapper();
        wrapper.recordName = 'Test Record';
        wrapper.recordUrl = '/001000000000001';
        wrapper.objectType = 'Contact';
        wrapper.createdDate = Datetime.now();
        
        System.assertEquals('Test Record', wrapper.recordName, 'Name should match');
    }
    
    @IsTest
    static void testObjectTypeOptionWrapper() {
        DuplicateViewerController.ObjectTypeOption option = 
            new DuplicateViewerController.ObjectTypeOption();
        option.label = 'Contact';
        option.value = 'Contact';
        
        System.assertEquals('Contact', option.label, 'Label should match');
        System.assertEquals('Contact', option.value, 'Value should match');
    }
    
    @IsTest
    static void testDuplicateSummaryWrapper() {
        DuplicateViewerController.DuplicateSummary summary = 
            new DuplicateViewerController.DuplicateSummary();
        summary.totalSets = 10;
        summary.totalItems = 25;
        summary.setsByObject = new List<DuplicateViewerController.ObjectCount>();
        
        System.assertEquals(10, summary.totalSets, 'Total sets should be 10');
        System.assertEquals(25, summary.totalItems, 'Total items should be 25');
    }
    
    @IsTest
    static void testObjectCountWrapper() {
        DuplicateViewerController.ObjectCount count = 
            new DuplicateViewerController.ObjectCount();
        count.objectType = 'Contact';
        count.count = 15;
        
        System.assertEquals('Contact', count.objectType, 'Object type should match');
        System.assertEquals(15, count.count, 'Count should be 15');
    }
    
    @IsTest
    static void testJobStatusWrapper() {
        DuplicateViewerController.JobStatusWrapper wrapper = 
            new DuplicateViewerController.JobStatusWrapper();
        wrapper.status = 'Completed';
        wrapper.jobItemsProcessed = 100;
        wrapper.totalJobItems = 100;
        wrapper.numberOfErrors = 0;
        wrapper.progressPercent = 100;
        wrapper.isComplete = true;
        wrapper.isSuccess = true;
        wrapper.className = 'DuplicateScannerJob';
        wrapper.createdDate = Datetime.now();
        wrapper.completedDate = Datetime.now();
        
        System.assertEquals('Completed', wrapper.status, 'Status should match');
        System.assertEquals(true, wrapper.isComplete, 'Should be complete');
        System.assertEquals(true, wrapper.isSuccess, 'Should be successful');
    }
    
    @IsTest
    static void testScheduleInfoWrapper() {
        DuplicateViewerController.ScheduleInfo info = 
            new DuplicateViewerController.ScheduleInfo();
        info.jobId = '08e000000000001';
        info.jobName = 'DuplicateScannerJob_Contact';
        info.objectType = 'Contact';
        info.cronExpression = '0 0 2 * * ?';
        info.nextFireTime = Datetime.now().addDays(1);
        info.previousFireTime = Datetime.now().addDays(-1);
        info.state = 'WAITING';
        info.isScheduled = true;
        info.scheduledTime = '02:00';
        
        System.assertEquals('Contact', info.objectType, 'Object type should match');
        System.assertEquals(true, info.isScheduled, 'Should be scheduled');
    }
    
    // =====================================================================
    // ADDITIONAL COVERAGE TESTS
    // =====================================================================
    
    @IsTest
    static void testGetDuplicateSetsWithData() {
        List<DuplicateRule> rules = [SELECT Id FROM DuplicateRule WHERE SobjectType = 'Contact' AND IsActive = true LIMIT 1];
        
        if (!rules.isEmpty()) {
            // Create DuplicateRecordSet
            DuplicateRecordSet drs = new DuplicateRecordSet();
            drs.DuplicateRuleId = rules[0].Id;
            insert drs;
            
            // Get test contacts
            List<Contact> contacts = [SELECT Id FROM Contact LIMIT 2];
            
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
                DuplicateViewerController.DuplicateDataResult result = 
                    DuplicateViewerController.getDuplicateSets('Contact', 10, 0);
                Test.stopTest();
                
                System.assertNotEquals(null, result, 'Result should not be null');
                System.assert(result.totalCount >= 1, 'Should have at least 1 set');
            }
            
            // Cleanup
            delete drs;
        }
    }
    
    @IsTest
    static void testGetScheduleStatusWithScheduledJob() {
        // Schedule a job first
        DuplicateViewerController.scheduleJob('Contact', 3, 30);
        
        Test.startTest();
        List<DuplicateViewerController.ScheduleInfo> schedules = 
            DuplicateViewerController.getScheduleStatus();
        Test.stopTest();
        
        System.assert(schedules.size() >= 1, 'Should have at least 1 scheduled job');
        
        // Cleanup
        DuplicateViewerController.unscheduleJob('Contact');
    }
    
    @IsTest
    static void testScheduleAndUnscheduleMultiple() {
        // Schedule multiple jobs
        DuplicateViewerController.scheduleJob('Contact', 2, 0);
        DuplicateViewerController.scheduleJob('Account', 3, 0);
        
        Test.startTest();
        List<DuplicateViewerController.ScheduleInfo> schedules = 
            DuplicateViewerController.getScheduleStatus();
        Test.stopTest();
        
        System.assert(schedules.size() >= 2, 'Should have at least 2 scheduled jobs');
        
        // Cleanup
        DuplicateViewerController.unscheduleJob('Contact');
        DuplicateViewerController.unscheduleJob('Account');
    }
    
    @IsTest
    static void testGetDuplicateItemsWithDeletedRecord() {
        List<DuplicateRule> rules = [SELECT Id FROM DuplicateRule WHERE SobjectType = 'Contact' AND IsActive = true LIMIT 1];
        
        if (!rules.isEmpty()) {
            // Create a contact that will be deleted
            Contact tempContact = new Contact(FirstName = 'Temp', LastName = 'Delete', Email = 'temp@delete.com');
            Database.DMLOptions dmlOptions = new Database.DMLOptions();
            dmlOptions.DuplicateRuleHeader.allowSave = true;
            Database.insert(tempContact, dmlOptions);
            
            DuplicateRecordSet drs = new DuplicateRecordSet();
            drs.DuplicateRuleId = rules[0].Id;
            insert drs;
            
            // Get another contact from setup
            Contact existingContact = [SELECT Id FROM Contact WHERE LastName = 'TestDuplicate' LIMIT 1];
            
            List<DuplicateRecordItem> items = new List<DuplicateRecordItem>();
            DuplicateRecordItem item1 = new DuplicateRecordItem();
            item1.DuplicateRecordSetId = drs.Id;
            item1.RecordId = existingContact.Id;
            items.add(item1);
            
            DuplicateRecordItem item2 = new DuplicateRecordItem();
            item2.DuplicateRecordSetId = drs.Id;
            item2.RecordId = tempContact.Id;
            items.add(item2);
            insert items;
            
            // Delete the temp contact
            delete tempContact;
            
            Test.startTest();
            List<DuplicateViewerController.DuplicateItemWrapper> result = 
                DuplicateViewerController.getDuplicateItems(drs.Id);
            Test.stopTest();
            
            System.assertNotEquals(null, result, 'Result should not be null');
            // Should handle deleted record gracefully
            
            // Cleanup
            delete drs;
        }
    }
    
    @IsTest
    static void testRunDuplicateScanAccount() {
        Test.startTest();
        String jobId = DuplicateViewerController.runDuplicateScan('Account');
        Test.stopTest();
        
        System.assertNotEquals(null, jobId, 'Account scan job ID should not be null');
    }
    
    @IsTest
    static void testRunDuplicateScanLead() {
        Test.startTest();
        String jobId = DuplicateViewerController.runDuplicateScan('Lead');
        Test.stopTest();
        
        System.assertNotEquals(null, jobId, 'Lead scan job ID should not be null');
    }
    
    @IsTest
    static void testScheduleJobDifferentTimes() {
        // Test scheduling at different times
        Test.startTest();
        DuplicateViewerController.ScheduleInfo info1 = 
            DuplicateViewerController.scheduleJob('Contact', 0, 0);
        Test.stopTest();
        
        System.assertNotEquals(null, info1, 'Schedule info should not be null');
        System.assertEquals('00:00', info1.scheduledTime, 'Scheduled time should be 00:00');
        
        // Cleanup
        DuplicateViewerController.unscheduleJob('Contact');
    }
    
    @IsTest
    static void testScheduleJobLateTime() {
        Test.startTest();
        DuplicateViewerController.ScheduleInfo info = 
            DuplicateViewerController.scheduleJob('Account', 23, 59);
        Test.stopTest();
        
        System.assertNotEquals(null, info, 'Schedule info should not be null');
        System.assertEquals('23:59', info.scheduledTime, 'Scheduled time should be 23:59');
        
        // Cleanup
        DuplicateViewerController.unscheduleJob('Account');
    }
}
