/**
 * @description Controller for the Duplicate Viewer LWC component.
 *              Provides methods to query and manage duplicate record sets.
 * @author Generated for Teachiq
 * @since 2026
 * @group Duplicate Management
 */
public with sharing class DuplicateViewerController {
    
    /**
     * @description Retrieves duplicate record sets with their associated items.
     *              NOT cacheable to ensure fresh data on refresh.
     * @param objectType Optional filter for specific object type (e.g., 'Contact', 'Account')
     * @param limitCount Maximum number of sets to return
     * @param offsetCount Offset for pagination
     * @return List of DuplicateSetWrapper containing set info and items
     */
    @AuraEnabled
    public static DuplicateDataResult getDuplicateSets(String objectType, Integer limitCount, Integer offsetCount) {
        try {
            DuplicateDataResult result = new DuplicateDataResult();
            
            // Build query for duplicate sets
            String query = 'SELECT Id, Name, RecordCount, DuplicateRuleId, DuplicateRule.MasterLabel, ' +
                          'DuplicateRule.SobjectType, CreatedDate, LastModifiedDate ' +
                          'FROM DuplicateRecordSet ';
            
            if (String.isNotBlank(objectType) && objectType != 'All') {
                query += 'WHERE DuplicateRule.SobjectType = :objectType ';
            }
            
            query += 'ORDER BY CreatedDate DESC ';
            query += 'LIMIT :limitCount OFFSET :offsetCount';
            
            List<DuplicateRecordSet> sets = Database.query(query);
            
            // Get total count for pagination
            String countQuery = 'SELECT COUNT() FROM DuplicateRecordSet';
            if (String.isNotBlank(objectType) && objectType != 'All') {
                countQuery += ' WHERE DuplicateRule.SobjectType = :objectType';
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
            throw new AuraHandledException('Error fetching duplicate sets: ' + e.getMessage());
        }
    }
    
    /**
     * @description Retrieves items (records) for a specific duplicate set.
     * @param duplicateSetId The ID of the DuplicateRecordSet
     * @return List of DuplicateItemWrapper with record details
     */
    @AuraEnabled
    public static List<DuplicateItemWrapper> getDuplicateItems(Id duplicateSetId) {
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
            String objectType = firstRecordId.getSObjectType().getDescribe().getName();
            
            // Collect all record IDs
            Set<Id> recordIds = new Set<Id>();
            for (DuplicateRecordItem item : recordItems) {
                recordIds.add(item.RecordId);
            }
            
            // Query the actual records with Name field
            String recordQuery = 'SELECT Id, Name FROM ' + String.escapeSingleQuotes(objectType) + 
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
            throw new AuraHandledException('Error fetching duplicate items: ' + e.getMessage());
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
                WHERE IsActive = true
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
            throw new AuraHandledException('Error fetching object types: ' + e.getMessage());
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
            throw new AuraHandledException('Error deleting duplicate set: ' + e.getMessage());
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
            throw new AuraHandledException('Error running duplicate scan: ' + e.getMessage());
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
                SELECT Id, Status, JobItemsProcessed, TotalJobItems, 
                       NumberOfErrors, ExtendedStatus, CreatedDate, CompletedDate,
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
                wrapper.progressPercent = (job.JobItemsProcessed * 100) / job.TotalJobItems;
            } else {
                // For Queueable jobs, TotalJobItems might be 0
                wrapper.progressPercent = job.Status == 'Completed' ? 100 : 50;
            }
            
            // Determine if job is complete
            wrapper.isComplete = job.Status == 'Completed' || 
                                 job.Status == 'Failed' || 
                                 job.Status == 'Aborted';
            
            // Determine if job succeeded
            wrapper.isSuccess = job.Status == 'Completed' && job.NumberOfErrors == 0;
            
            return wrapper;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching job status: ' + e.getMessage());
        }
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
                SELECT Id, Status, JobItemsProcessed, TotalJobItems, 
                       NumberOfErrors, ExtendedStatus, CreatedDate, CompletedDate,
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
                    wrapper.progressPercent = (job.JobItemsProcessed * 100) / job.TotalJobItems;
                } else {
                    wrapper.progressPercent = job.Status == 'Completed' ? 100 : 50;
                }
                
                wrapper.isComplete = job.Status == 'Completed' || 
                                     job.Status == 'Failed' || 
                                     job.Status == 'Aborted';
                wrapper.isSuccess = job.Status == 'Completed' && job.NumberOfErrors == 0;
                
                wrappers.add(wrapper);
            }
            
            return wrappers;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching recent jobs: ' + e.getMessage());
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
            throw new AuraHandledException('Error fetching summary: ' + e.getMessage());
        }
    }
    
    // =====================================================================
    // WRAPPER CLASSES
    // =====================================================================
    
    public class DuplicateDataResult {
        @AuraEnabled public List<DuplicateSetWrapper> duplicateSets;
        @AuraEnabled public Integer totalCount;
    }
    
    public class DuplicateSetWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Integer recordCount;
        @AuraEnabled public String ruleName;
        @AuraEnabled public String objectType;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Datetime lastModifiedDate;
        @AuraEnabled public Id duplicateRuleId;
    }
    
    public class DuplicateItemWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public Id recordId;
        @AuraEnabled public String recordName;
        @AuraEnabled public String recordUrl;
        @AuraEnabled public String objectType;
        @AuraEnabled public Datetime createdDate;
    }
    
    public class ObjectTypeOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }
    
    public class DuplicateSummary {
        @AuraEnabled public Integer totalSets;
        @AuraEnabled public Integer totalItems;
        @AuraEnabled public List<ObjectCount> setsByObject;
    }
    
    public class ObjectCount {
        @AuraEnabled public String objectType;
        @AuraEnabled public Integer count;
    }
    
    public class JobStatusWrapper {
        @AuraEnabled public Id jobId;
        @AuraEnabled public String status;
        @AuraEnabled public Integer jobItemsProcessed;
        @AuraEnabled public Integer totalJobItems;
        @AuraEnabled public Integer numberOfErrors;
        @AuraEnabled public String extendedStatus;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Datetime completedDate;
        @AuraEnabled public String className;
        @AuraEnabled public Integer progressPercent;
        @AuraEnabled public Boolean isComplete;
        @AuraEnabled public Boolean isSuccess;
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
                SELECT Id, CronJobDetail.Name, CronExpression, NextFireTime, 
                       PreviousFireTime, State, TimesTriggered
                FROM CronTrigger 
                WHERE CronJobDetail.Name LIKE 'DuplicateScannerJob_%'
                ORDER BY CronJobDetail.Name
            ];
            
            for (CronTrigger ct : cronJobs) {
                ScheduleInfo info = new ScheduleInfo();
                info.jobId = ct.Id;
                info.jobName = ct.CronJobDetail.Name;
                info.objectType = ct.CronJobDetail.Name.replace(SCHEDULE_JOB_PREFIX, '');
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
            throw new AuraHandledException('Error fetching schedule status: ' + e.getMessage());
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
    public static ScheduleInfo scheduleJob(String objectType, Integer hour, Integer minute) {
        try {
            if (String.isBlank(objectType) || objectType == 'All') {
                throw new AuraHandledException('Please select a specific object type to schedule.');
            }
            
            // First, unschedule any existing job for this object type
            unscheduleJobInternal(objectType);
            
            // Build cron expression for daily at specified time
            // Format: Seconds Minutes Hours Day_of_month Month Day_of_week Year
            String cronExp = String.format('0 {0} {1} * * ?', new List<Object>{ minute, hour });
            
            // Schedule the job
            String jobName = SCHEDULE_JOB_PREFIX + objectType;
            DuplicateScannerScheduler scheduler = new DuplicateScannerScheduler(objectType);
            String jobId = System.schedule(jobName, cronExp, scheduler);
            
            // Return schedule info
            ScheduleInfo info = new ScheduleInfo();
            info.jobId = jobId;
            info.jobName = jobName;
            info.objectType = objectType;
            info.cronExpression = cronExp;
            info.isScheduled = true;
            info.scheduledTime = String.format('{0}:{1}', new List<Object>{ 
                String.valueOf(hour).leftPad(2, '0'), 
                String.valueOf(minute).leftPad(2, '0') 
            });
            
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
            throw new AuraHandledException('Error unscheduling job: ' + e.getMessage());
        }
    }
    
    /**
     * @description Internal method to unschedule a job.
     */
    private static void unscheduleJobInternal(String objectType) {
        String jobName = SCHEDULE_JOB_PREFIX + objectType;
        
        List<CronTrigger> existingJobs = [
            SELECT Id FROM CronTrigger 
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
        @AuraEnabled public String jobId;
        @AuraEnabled public String jobName;
        @AuraEnabled public String objectType;
        @AuraEnabled public String cronExpression;
        @AuraEnabled public Datetime nextFireTime;
        @AuraEnabled public Datetime previousFireTime;
        @AuraEnabled public String state;
        @AuraEnabled public Boolean isScheduled;
        @AuraEnabled public String scheduledTime; // HH:MM format
    }
}
