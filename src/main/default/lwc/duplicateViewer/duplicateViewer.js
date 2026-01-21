import { LightningElement, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getDuplicateSetPreviews from "@salesforce/apex/DuplicateViewerController.getDuplicateSetPreviews";
import getObjectTypeOptions from "@salesforce/apex/DuplicateViewerController.getObjectTypeOptions";
import getDuplicateSummary from "@salesforce/apex/DuplicateViewerController.getDuplicateSummary";
import deleteDuplicateSet from "@salesforce/apex/DuplicateViewerController.deleteDuplicateSet";
import runDuplicateScan from "@salesforce/apex/DuplicateViewerController.runDuplicateScan";
import getJobStatus from "@salesforce/apex/DuplicateViewerController.getJobStatus";
import getRecentJobs from "@salesforce/apex/DuplicateViewerController.getRecentJobs";
import getScheduleStatus from "@salesforce/apex/DuplicateViewerController.getScheduleStatus";
import scheduleJob from "@salesforce/apex/DuplicateViewerController.scheduleJob";
import unscheduleJob from "@salesforce/apex/DuplicateViewerController.unscheduleJob";
import abortJob from "@salesforce/apex/DuplicateViewerController.abortJob";

const PAGE_SIZE = 12;
const JOB_POLL_INTERVAL = 2000; // 2 seconds

export default class DuplicateViewer extends LightningElement {
  // Data
  @track duplicateSets = [];
  @track objectTypeOptions = [];
  @track summary = {
    totalSets: 0,
    totalItems: 0,
    setsByObject: []
  };
  @track recentJobs = [];
  @track currentJob = null;
  @track scanningObjectType = "";

  // State
  @track isLoading = true;
  @track isRefreshing = false;
  @track error = null;
  @track selectedObjectType = "All";
  @track showJobPanel = false;
  @track searchTerm = "";

  // Merge Modal State
  @track showMergeModal = false;
  @track mergeSetId = null;

  // Schedule State
  @track showSchedulePanel = false;
  @track schedules = [];
  @track scheduleTime = "02:00"; // Default to 2 AM

  // Pagination
  @track currentPage = 1;
  @track totalCount = 0;

  // Job polling
  _jobPollInterval = null;

  // Search debounce
  _searchDebounceTimeout = null;

  // =========================================================================
  // LIFECYCLE
  // =========================================================================

  connectedCallback() {
    this.loadAllData();
  }

  disconnectedCallback() {
    this.stopJobPolling();
  }

  // =========================================================================
  // WIRE ADAPTERS
  // =========================================================================

  @wire(getObjectTypeOptions)
  wiredObjectTypes({ error, data }) {
    if (data) {
      this.objectTypeOptions = data.map((opt) => ({
        label: opt.label,
        value: opt.value
      }));
    } else if (error) {
      console.error("Error loading object types:", error);
    }
  }

  // =========================================================================
  // DATA LOADING
  // =========================================================================

  async loadAllData() {
    this.isLoading = true;
    this.error = null;

    try {
      await Promise.all([
        this.loadDuplicateSets(),
        this.loadSummary(),
        this.loadRecentJobs()
      ]);
    } catch (err) {
      this.error = this.extractErrorMessage(err);
    } finally {
      this.isLoading = false;
      this.isRefreshing = false;
    }
  }

  async loadDuplicateSets() {
    const result = await getDuplicateSetPreviews({
      objectType: this.selectedObjectType,
      searchTerm: this.searchTerm,
      limitCount: PAGE_SIZE,
      offsetCount: (this.currentPage - 1) * PAGE_SIZE
    });

    // Process preview data for display
    const processedSets = (result.duplicateSets || []).map((set) => {
      const processedSet = { ...set };

      // Process sample records and calculate differing/identical fields
      if (set.sampleRecords && set.sampleRecords.length > 0) {
        // Build field displays for compact view
        const differingFieldDisplays = [];
        const identicalFieldDisplays = [];
        const firstRecord = set.sampleRecords[0];
        const secondRecord = set.sampleRecords[1];

        // If we have fieldDifferences from server, use that
        const labels = set.fieldLabels || {};
        if (set.fieldDifferences) {
          for (const fieldName in set.fieldDifferences) {
            if (
              Object.prototype.hasOwnProperty.call(
                set.fieldDifferences,
                fieldName
              )
            ) {
              const value1 = firstRecord?.fieldValues?.[fieldName];
              const value2 = secondRecord?.fieldValues?.[fieldName];
              const label = labels[fieldName] || fieldName;

              if (set.fieldDifferences[fieldName] === true && secondRecord) {
                // Field has different values - show comparison
                const formattedValue1 = this.formatFieldValue(value1);
                const formattedValue2 = this.formatFieldValue(value2);
                differingFieldDisplays.push({
                  fieldName: fieldName,
                  label: label,
                  value1: formattedValue1,
                  value2: formattedValue2,
                  value1Empty: !formattedValue1,
                  value2Empty: !formattedValue2
                });
              } else {
                // Field has identical values - show once
                identicalFieldDisplays.push({
                  fieldName: fieldName,
                  label: label,
                  value: this.formatFieldValue(value1)
                });
              }
            }
          }
        } else if (firstRecord?.fieldValues) {
          // Fallback: no fieldDifferences, just show first record's fields once
          const fallbackLabels = set.fieldLabels || {};
          for (const fieldName in firstRecord.fieldValues) {
            if (
              Object.prototype.hasOwnProperty.call(
                firstRecord.fieldValues,
                fieldName
              )
            ) {
              const value = firstRecord.fieldValues[fieldName];
              const label = fallbackLabels[fieldName] || fieldName;
              identicalFieldDisplays.push({
                fieldName: fieldName,
                label: label,
                value: this.formatFieldValue(value)
              });
            }
          }
        }

        processedSet.differingFieldDisplays = differingFieldDisplays;
        processedSet.identicalFieldDisplays = identicalFieldDisplays;
        processedSet.hasDifferences = differingFieldDisplays.length > 0;
        processedSet.hasIdenticalFields = identicalFieldDisplays.length > 0;
        processedSet.hasAnyFields =
          differingFieldDisplays.length > 0 ||
          identicalFieldDisplays.length > 0;
        // Store first record name for display (LWC templates don't allow array index access)
        processedSet.firstRecordName = firstRecord?.recordName || "";

        // Also keep the original fieldDisplays for the first record
        processedSet.sampleRecords = set.sampleRecords.map((record) => {
          const fieldDisplays = [];

          if (record.fieldValues && set.fieldLabels) {
            for (const fieldName in record.fieldValues) {
              if (
                Object.prototype.hasOwnProperty.call(
                  record.fieldValues,
                  fieldName
                )
              ) {
                const value = record.fieldValues[fieldName];
                const label = set.fieldLabels[fieldName] || fieldName;
                const displayValue = this.formatFieldValue(value);

                fieldDisplays.push({
                  apiName: fieldName,
                  label: label,
                  displayValue: displayValue,
                  fullValue: String(value || "")
                });
              }
            }
          }

          return {
            ...record,
            fieldDisplays: fieldDisplays
          };
        });
      }

      return processedSet;
    });

    this.duplicateSets = processedSets;
    this.totalCount = result.totalCount || 0;
  }

  async loadSummary() {
    const summaryData = await getDuplicateSummary();
    this.summary = {
      totalSets: summaryData.totalSets || 0,
      totalItems: summaryData.totalItems || 0,
      setsByObject: summaryData.setsByObject || []
    };
  }

  async loadRecentJobs() {
    const jobs = await getRecentJobs();
    this.recentJobs = jobs || [];

    // Check if there's a running job
    const runningJob = this.recentJobs.find((j) => !j.isComplete);
    if (runningJob) {
      this.currentJob = runningJob;
      this.startJobPolling(runningJob.jobId);
    }
  }

  // =========================================================================
  // JOB POLLING
  // =========================================================================

  startJobPolling(jobId) {
    this.stopJobPolling();

    this._jobPollInterval = setInterval(async () => {
      try {
        const status = await getJobStatus({ jobId });
        this.currentJob = status;

        if (status.isComplete) {
          this.stopJobPolling();

          if (status.isSuccess) {
            this.showToast(
              "Success",
              "Duplicate scan completed successfully!",
              "success"
            );
          } else if (status.status === "Failed") {
            this.showToast(
              "Error",
              `Scan failed: ${status.extendedStatus || "Unknown error"}`,
              "error"
            );
          }

          // Refresh data after job completes
          await this.loadAllData();
        }
      } catch (err) {
        console.error("Error polling job status:", err);
        this.stopJobPolling();
      }
    }, JOB_POLL_INTERVAL);
  }

  stopJobPolling() {
    if (this._jobPollInterval) {
      clearInterval(this._jobPollInterval);
      this._jobPollInterval = null;
    }
  }

  // =========================================================================
  // COMPUTED PROPERTIES
  // =========================================================================

  get showEmptyState() {
    return !this.isLoading && !this.error && this.duplicateSets.length === 0;
  }

  get showDuplicateSets() {
    return !this.isLoading && !this.error && this.duplicateSets.length > 0;
  }

  get totalPages() {
    return Math.ceil(this.totalCount / PAGE_SIZE) || 1;
  }

  get showPagination() {
    return this.totalPages > 1;
  }

  get isPrevDisabled() {
    return this.currentPage <= 1;
  }

  get isNextDisabled() {
    return this.currentPage >= this.totalPages;
  }

  get isRunScanDisabled() {
    return this.selectedObjectType === "All" || this.hasRunningJob;
  }

  get hasRunningJob() {
    return this.currentJob && !this.currentJob.isComplete;
  }

  get runningJobStatus() {
    if (!this.currentJob) return "";
    return this.currentJob.status;
  }

  get runningJobProgress() {
    if (!this.currentJob) return 0;
    return this.currentJob.progressPercent || 0;
  }

  get jobStatusClass() {
    if (!this.currentJob) return "";
    if (this.currentJob.isComplete && this.currentJob.isSuccess)
      return "job-success";
    if (this.currentJob.isComplete && !this.currentJob.isSuccess)
      return "job-failed";
    return "job-running";
  }

  get refreshButtonLabel() {
    return this.isRefreshing ? "Refreshing..." : "Refresh";
  }

  get refreshButtonDisabled() {
    return this.isRefreshing;
  }

  get progressStyle() {
    const percent = this.runningJobProgress || 0;
    return `width: ${percent}%`;
  }

  get filteredDuplicateSets() {
    // Server now handles filtering via SOQL, just return the results
    return this.duplicateSets;
  }

  get searchResultsMessage() {
    if (!this.searchTerm) {
      return "";
    }
    // Now shows server-filtered results count
    return `Found ${this.totalCount} set${this.totalCount !== 1 ? "s" : ""} matching "${this.searchTerm}"`;
  }

  get showSearchResults() {
    return this.searchTerm && this.searchTerm.length > 0;
  }

  // =========================================================================
  // EVENT HANDLERS
  // =========================================================================

  handleObjectTypeChange(event) {
    this.selectedObjectType = event.detail.value;
    this.currentPage = 1;
    this.isLoading = true;
    this.loadAllData();
  }

  handleSummaryCardClick(event) {
    const objectType = event.currentTarget.dataset.object;
    if (objectType) {
      this.selectedObjectType = objectType;
      this.currentPage = 1;
      this.isLoading = true;
      this.loadAllData();
    }
  }

  handleSearchChange(event) {
    this.searchTerm = event.target.value;

    // Debounce server calls (300ms delay)
    clearTimeout(this._searchDebounceTimeout);
    this._searchDebounceTimeout = setTimeout(() => {
      this.currentPage = 1; // Reset to first page on new search
      this.isLoading = true;
      this.loadAllData();
    }, 300);
  }

  async handleRefresh() {
    this.isRefreshing = true;
    await this.loadAllData();
  }

  async handleRunScan() {
    if (this.selectedObjectType === "All") {
      this.showToast(
        "Info",
        "Please select a specific object type to scan.",
        "info"
      );
      return;
    }

    if (this.hasRunningJob) {
      this.showToast(
        "Info",
        "A scan is already in progress. Please wait for it to complete.",
        "info"
      );
      return;
    }

    // Warn user about deletion of existing duplicate sets and potential long wait time
    const warningMessage =
      `Warning: Starting a new scan will delete all existing Duplicate Record Sets for ${this.selectedObjectType}.\n\n` +
      `If your org has a large number of records, this scan may take a significant amount of time to complete.\n\n` +
      `Do you want to proceed?`;

    // eslint-disable-next-line no-restricted-globals, no-alert
    if (!confirm(warningMessage)) {
      return;
    }

    try {
      const jobId = await runDuplicateScan({
        objectType: this.selectedObjectType
      });

      this.scanningObjectType = this.selectedObjectType;
      this.currentJob = {
        jobId: jobId,
        status: "Queued",
        progressPercent: 0,
        isComplete: false,
        isSuccess: false
      };

      this.showToast(
        "Success",
        `Duplicate scan started for ${this.selectedObjectType}. Monitoring progress...`,
        "success"
      );

      this.startJobPolling(jobId);
    } catch (err) {
      this.showToast("Error", this.extractErrorMessage(err), "error");
    }
  }

  async handleStopScan() {
    if (!this.currentJob || !this.currentJob.jobId) {
      return;
    }

    // eslint-disable-next-line no-restricted-globals, no-alert
    if (!confirm("Are you sure you want to stop the scan?")) {
      return;
    }

    try {
      await abortJob({ jobId: this.currentJob.jobId });
      this.stopJobPolling();
      this.currentJob = null;
      this.scanningObjectType = "";
      this.showToast("Info", "Scan has been stopped.", "info");
      await this.loadAllData();
    } catch (err) {
      this.showToast("Error", this.extractErrorMessage(err), "error");
    }
  }

  handleSetClick(event) {
    const setId = event.currentTarget.dataset.id;
    // Don't open modal if clicking the delete or merge button
    if (
      event.target.closest(".delete-btn") ||
      event.target.closest(".merge-btn")
    ) {
      return;
    }
    // Navigate directly to merge modal
    this.mergeSetId = setId;
    this.showMergeModal = true;
  }

  handleMergeClick(event) {
    event.stopPropagation();
    const setId = event.currentTarget.dataset.id;
    this.mergeSetId = setId;
    this.showMergeModal = true;
  }

  closeMergeModal() {
    this.showMergeModal = false;
    this.mergeSetId = null;
  }

  async handleMergeComplete(_event) {
    // Don't close modal - let user see success state and choose to navigate or close
    // Just reload data in background
    await this.loadAllData();
  }

  async handleDeleteSet(event) {
    event.stopPropagation();
    const setId = event.currentTarget.dataset.id;

    // eslint-disable-next-line no-restricted-globals, no-alert
    if (!confirm("Are you sure you want to delete this duplicate set?")) {
      return;
    }

    try {
      // Optimistically remove from UI immediately
      this.duplicateSets = this.duplicateSets.filter((s) => s.id !== setId);
      this.totalCount = Math.max(0, this.totalCount - 1);

      // Update summary counts
      this.summary = {
        ...this.summary,
        totalSets: Math.max(0, this.summary.totalSets - 1)
      };

      // Actually delete
      await deleteDuplicateSet({ setId });

      this.showToast(
        "Success",
        "Duplicate set deleted successfully.",
        "success"
      );

      // Reload to get accurate counts
      await this.loadSummary();
    } catch (err) {
      this.showToast("Error", this.extractErrorMessage(err), "error");
      // Reload data to restore correct state
      await this.loadAllData();
    }
  }

  handlePrevPage() {
    if (this.currentPage > 1) {
      this.currentPage--;
      this.isLoading = true;
      this.loadAllData();
    }
  }

  handleNextPage() {
    if (this.currentPage < this.totalPages) {
      this.currentPage++;
      this.isLoading = true;
      this.loadAllData();
    }
  }

  toggleJobPanel() {
    this.showJobPanel = !this.showJobPanel;
  }

  // =========================================================================
  // SCHEDULING METHODS
  // =========================================================================

  handleToggleSchedulePanel() {
    this.showSchedulePanel = !this.showSchedulePanel;
    if (this.showSchedulePanel) {
      this.loadScheduleStatus();
    }
  }

  async loadScheduleStatus() {
    try {
      this.schedules = await getScheduleStatus();
      // Update schedule time if there's an active schedule for current object
      const activeSchedule = this.currentObjectSchedule;
      if (activeSchedule && activeSchedule.scheduledTime) {
        this.scheduleTime = activeSchedule.scheduledTime;
      }
    } catch (err) {
      console.error("Error loading schedule status:", err);
    }
  }

  handleScheduleTimeChange(event) {
    this.scheduleTime = event.target.value;
  }

  async handleScheduleJob() {
    if (this.isScheduleDisabled) return;

    try {
      const [hour, minute] = this.scheduleTime.split(":").map(Number);

      await scheduleJob({
        objectType: this.selectedObjectType,
        hour: hour,
        minute: minute
      });

      this.showToast(
        "Success",
        `Daily scan scheduled for ${this.selectedObjectType} at ${this.scheduleTime}`,
        "success"
      );

      await this.loadScheduleStatus();
    } catch (err) {
      this.showToast("Error", this.extractErrorMessage(err), "error");
    }
  }

  async handleUnscheduleJob() {
    if (this.isScheduleDisabled) return;

    try {
      await unscheduleJob({ objectType: this.selectedObjectType });

      this.showToast(
        "Success",
        `Daily scan cancelled for ${this.selectedObjectType}`,
        "success"
      );

      await this.loadScheduleStatus();
    } catch (err) {
      this.showToast("Error", this.extractErrorMessage(err), "error");
    }
  }

  get currentObjectSchedule() {
    if (!this.schedules || this.selectedObjectType === "All") {
      return null;
    }
    return this.schedules.find((s) => s.objectType === this.selectedObjectType);
  }

  get hasActiveSchedule() {
    const schedule = this.currentObjectSchedule;
    return schedule && schedule.isScheduled;
  }

  get activeScheduleTime() {
    const schedule = this.currentObjectSchedule;
    return schedule ? schedule.scheduledTime : "";
  }

  get nextFireTime() {
    const schedule = this.currentObjectSchedule;
    return schedule ? schedule.nextFireTime : null;
  }

  get isScheduleDisabled() {
    return !this.selectedObjectType || this.selectedObjectType === "All";
  }

  // =========================================================================
  // UTILITIES
  // =========================================================================

  formatFieldValue(value) {
    if (value === null || value === undefined) {
      return "";
    }

    // Handle boolean values
    if (typeof value === "boolean") {
      return value ? "Yes" : "No";
    }

    // Handle dates
    if (typeof value === "string" && value.match(/^\d{4}-\d{2}-\d{2}/)) {
      try {
        const date = new Date(value);
        if (!isNaN(date.getTime())) {
          return date.toLocaleDateString();
        }
      } catch (e) {
        // Not a valid date, continue
      }
    }

    // Handle long strings (truncate for display)
    const strValue = String(value);
    if (strValue.length > 50) {
      return strValue.substring(0, 50) + "...";
    }

    return strValue;
  }

  extractErrorMessage(error) {
    if (typeof error === "string") {
      return error;
    }
    if (error.body && error.body.message) {
      return error.body.message;
    }
    if (error.message) {
      return error.message;
    }
    return "An unknown error occurred.";
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }
}
