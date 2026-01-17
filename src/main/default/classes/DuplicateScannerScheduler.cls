/**
 * @description Schedulable wrapper class for the DuplicateScannerJob.
 *              Allows scheduling periodic duplicate scans for one or more object types.
 *
 * USAGE EXAMPLES:
 *
 * 1. Schedule a weekly scan for Contacts:
 *    DuplicateScannerScheduler.scheduleWeekly('Contact');
 *
 * 2. Schedule a daily scan for Accounts:
 *    DuplicateScannerScheduler.scheduleDaily('Account');
 *
 * 3. Schedule with custom cron expression:
 *    DuplicateScannerScheduler.schedule('Contact', '0 0 3 ? * SAT');
 *
 * 4. Execute immediately via Developer Console:
 *    DuplicateScannerScheduler.executeNow('Lead');
 *
 * 5. Schedule multiple objects:
 *    DuplicateScannerScheduler.scheduleWeekly(new List<String>{'Contact', 'Account', 'Lead'});
 *
 * @author Andrii Solokh
 * @since 2026
 * @group Duplicate Management
 */
public without sharing class DuplicateScannerScheduler implements Schedulable {
    // =====================================================================
    // CONSTANTS
    // =====================================================================

    /** Base job name prefix for scheduled jobs */
    private static final String JOB_NAME_PREFIX = 'Duplicate Scanner - ';

    /** Cron expression for weekly Sunday at 2 AM */
    private static final String WEEKLY_CRON = '0 0 2 ? * SUN';

    /** Cron expression for daily at 2 AM */
    private static final String DAILY_CRON = '0 0 2 * * ?';

    /** Cron expression for monthly on the 1st at 2 AM */
    private static final String MONTHLY_CRON = '0 0 2 1 * ?';

    // =====================================================================
    // INSTANCE VARIABLES
    // =====================================================================

    /** The API name of the object to scan for duplicates */
    private String objectApiName;

    /** Optional custom batch size */
    private Integer batchSize;

    // =====================================================================
    // CONSTRUCTORS
    // =====================================================================

    /**
     * @description Constructor for scheduling a duplicate scan for a specific object.
     * @param objectApiName The API name of the SObject to scan.
     */
    public DuplicateScannerScheduler(String objectApiName) {
        this(objectApiName, null);
    }

    /**
     * @description Constructor with custom batch size.
     * @param objectApiName The API name of the SObject to scan.
     * @param batchSize Custom batch size for the scan.
     */
    public DuplicateScannerScheduler(String objectApiName, Integer batchSize) {
        this.objectApiName = objectApiName;
        this.batchSize = batchSize;
    }

    // =====================================================================
    // SCHEDULABLE IMPLEMENTATION
    // =====================================================================

    /**
     * @description Executes the scheduled job by enqueueing a DuplicateScannerJob.
     * @param context The SchedulableContext provided by the Salesforce runtime.
     */
    public void execute(SchedulableContext context) {
        if (batchSize != null) {
            DuplicateScannerJob.execute(objectApiName, batchSize);
        } else {
            DuplicateScannerJob.execute(objectApiName);
        }
    }

    // =====================================================================
    // PUBLIC STATIC METHODS - SINGLE OBJECT
    // =====================================================================

    /**
     * @description Executes a duplicate scan immediately for the specified object.
     * @param objectApiName The API name of the SObject to scan.
     * @return The Job ID of the enqueued job.
     */
    public static Id executeNow(String objectApiName) {
        return DuplicateScannerJob.execute(objectApiName);
    }

    /**
     * @description Executes a duplicate scan immediately with custom batch size.
     * @param objectApiName The API name of the SObject to scan.
     * @param batchSize Custom batch size.
     * @return The Job ID of the enqueued job.
     */
    public static Id executeNow(String objectApiName, Integer batchSize) {
        return DuplicateScannerJob.execute(objectApiName, batchSize);
    }

    /**
     * @description Schedules a weekly duplicate scan for the specified object.
     *              Runs every Sunday at 2 AM.
     * @param objectApiName The API name of the SObject to scan.
     * @return The scheduled job ID.
     */
    public static String scheduleWeekly(String objectApiName) {
        return schedule(objectApiName, WEEKLY_CRON);
    }

    /**
     * @description Schedules a daily duplicate scan for the specified object.
     *              Runs every day at 2 AM.
     * @param objectApiName The API name of the SObject to scan.
     * @return The scheduled job ID.
     */
    public static String scheduleDaily(String objectApiName) {
        return schedule(objectApiName, DAILY_CRON);
    }

    /**
     * @description Schedules a monthly duplicate scan for the specified object.
     *              Runs on the 1st of each month at 2 AM.
     * @param objectApiName The API name of the SObject to scan.
     * @return The scheduled job ID.
     */
    public static String scheduleMonthly(String objectApiName) {
        return schedule(objectApiName, MONTHLY_CRON);
    }

    /**
     * @description Schedules a duplicate scan with a custom cron expression.
     * @param objectApiName The API name of the SObject to scan.
     * @param cronExpression The cron expression defining the schedule.
     * @return The scheduled job ID.
     */
    public static String schedule(String objectApiName, String cronExpression) {
        String jobName = JOB_NAME_PREFIX + objectApiName;
        return System.schedule(jobName, cronExpression, new DuplicateScannerScheduler(objectApiName));
    }

    /**
     * @description Schedules a duplicate scan with custom cron and batch size.
     * @param objectApiName The API name of the SObject to scan.
     * @param cronExpression The cron expression defining the schedule.
     * @param batchSize Custom batch size.
     * @return The scheduled job ID.
     */
    public static String schedule(String objectApiName, String cronExpression, Integer batchSize) {
        String jobName = JOB_NAME_PREFIX + objectApiName;
        return System.schedule(jobName, cronExpression, new DuplicateScannerScheduler(objectApiName, batchSize));
    }

    // =====================================================================
    // PUBLIC STATIC METHODS - MULTIPLE OBJECTS
    // =====================================================================

    /**
     * @description Schedules weekly duplicate scans for multiple objects.
     *              Each object gets its own scheduled job, staggered by 1 hour.
     * @param objectApiNames List of object API names to scan.
     * @return Map of object names to their scheduled job IDs.
     */
    public static Map<String, String> scheduleWeekly(List<String> objectApiNames) {
        Map<String, String> jobIds = new Map<String, String>();
        Integer hourOffset = 0;

        for (String objectApiName : objectApiNames) {
            // Stagger the jobs by 1 hour each to avoid resource contention
            String cronExpression = '0 0 ' + (2 + hourOffset) + ' ? * SUN';
            jobIds.put(objectApiName, schedule(objectApiName, cronExpression));
            hourOffset++;
        }

        return jobIds;
    }

    /**
     * @description Schedules daily duplicate scans for multiple objects.
     *              Each object gets its own scheduled job, staggered by 1 hour.
     * @param objectApiNames List of object API names to scan.
     * @return Map of object names to their scheduled job IDs.
     */
    public static Map<String, String> scheduleDaily(List<String> objectApiNames) {
        Map<String, String> jobIds = new Map<String, String>();
        Integer hourOffset = 0;

        for (String objectApiName : objectApiNames) {
            String cronExpression = '0 0 ' + (2 + hourOffset) + ' * * ?';
            jobIds.put(objectApiName, schedule(objectApiName, cronExpression));
            hourOffset++;
        }

        return jobIds;
    }

    // =====================================================================
    // UTILITY METHODS
    // =====================================================================

    /**
     * @description Aborts all scheduled duplicate scanner jobs.
     * @return The number of jobs aborted.
     */
    public static Integer abortAllScheduledJobs() {
        Integer count = 0;

        for (CronTrigger ct : [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'Duplicate Scanner%'
        ]) {
            System.abortJob(ct.Id);
            count++;
        }

        return count;
    }

    /**
     * @description Aborts the scheduled duplicate scanner job for a specific object.
     * @param objectApiName The API name of the object whose job should be aborted.
     * @return True if a job was aborted, false otherwise.
     */
    public static Boolean abortScheduledJob(String objectApiName) {
        String jobName = JOB_NAME_PREFIX + objectApiName;

        for (CronTrigger ct : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :jobName
        ]) {
            System.abortJob(ct.Id);
            return true;
        }

        return false;
    }

    /**
     * @description Gets the status of all scheduled duplicate scanner jobs.
     * @return Map of job names to their next fire times.
     */
    public static Map<String, Datetime> getScheduledJobsStatus() {
        Map<String, Datetime> status = new Map<String, Datetime>();

        for (CronTrigger ct : [
            SELECT CronJobDetail.Name, NextFireTime
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'Duplicate Scanner%'
            ORDER BY NextFireTime ASC
        ]) {
            status.put(ct.CronJobDetail.Name, ct.NextFireTime);
        }

        return status;
    }
}
