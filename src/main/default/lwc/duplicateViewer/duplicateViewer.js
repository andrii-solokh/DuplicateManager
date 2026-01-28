import { LightningElement, api, track, wire } from "lwc";
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
import hasAdminAccess from "@salesforce/apex/DuplicateViewerConfigController.hasAdminAccess";
import getFilterFields from "@salesforce/apex/DuplicateViewerController.getFilterFields";

const JOB_POLL_INTERVAL = 2000; // 2 seconds

export default class DuplicateViewer extends LightningElement {
  // Page size (configurable via Lightning App Builder)
  @api pageSize = 12;
  @track _effectivePageSize = 12;

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

  // Settings State
  @track showSettings = false;
  @track isAdmin = false;

  // Filter State
  @track filterFields = [];
  @track activeFilters = {};

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
    this._effectivePageSize = this.pageSize || 12;
    this.loadAllData();
    this.checkAdminAccess();
  }

  async checkAdminAccess() {
    try {
      this.isAdmin = await hasAdminAccess();
    } catch (err) {
      this.isAdmin = false;
    }
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
    // Build filter criteria JSON
    const filterCriteria = this.buildFilterCriteria();

    const result = await getDuplicateSetPreviews({
      objectType: this.selectedObjectType,
      searchTerm: this.searchTerm,
      limitCount: this._effectivePageSize,
      offsetCount: (this.currentPage - 1) * this._effectivePageSize,
      filterCriteria: filterCriteria
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
                // Field has identical values - show once (skip if empty)
                const formattedValue = this.formatFieldValue(value1);
                if (formattedValue) {
                  identicalFieldDisplays.push({
                    fieldName: fieldName,
                    label: label,
                    value: formattedValue
                  });
                }
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
              const formattedValue = this.formatFieldValue(value);
              // Skip empty values
              if (formattedValue) {
                identicalFieldDisplays.push({
                  fieldName: fieldName,
                  label: label,
                  value: formattedValue
                });
              }
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

      // Add badge style with SLDS color
      processedSet.badgeStyle = `background-color: ${this.getObjectColor(set.objectType)}`;

      return processedSet;
    });

    this.duplicateSets = processedSets;
    this.totalCount = result.totalCount || 0;
  }

  async loadSummary() {
    const summaryData = await getDuplicateSummary();
    // Add icon names to setsByObject
    const setsByObject = (summaryData.setsByObject || []).map((obj) => ({
      ...obj,
      iconName: this.getObjectIconName(obj.objectType),
      itemCount: obj.itemCount || 0,
      iconStyle: `background: ${this.getObjectColor(obj.objectType)}`
    }));
    this.summary = {
      totalSets: summaryData.totalSets || 0,
      totalItems: summaryData.totalItems || 0,
      setsByObject: setsByObject
    };
  }

  // SLDS standard object icon colors
  static OBJECT_COLORS = {
    account: "#7F8DE1",
    contact: "#A094ED",
    lead: "#F88962",
    case: "#F2CF5B",
    opportunity: "#FCB95B",
    campaign: "#7DC37D",
    task: "#4BC076",
    event: "#EB7092",
    user: "#65CAE4",
    record: "#9050E9"
  };

  getObjectIconName(objectType) {
    // Standard Salesforce object icons use lowercase names
    const standardObjects = Object.keys(DuplicateViewer.OBJECT_COLORS).filter(
      (k) => k !== "record"
    );
    const lowerType = (objectType || "").toLowerCase();
    if (standardObjects.includes(lowerType)) {
      return `standard:${lowerType}`;
    }
    // For custom objects, use custom icon
    return "standard:record";
  }

  getObjectColor(objectType) {
    const lowerType = (objectType || "").toLowerCase();
    return (
      DuplicateViewer.OBJECT_COLORS[lowerType] ||
      DuplicateViewer.OBJECT_COLORS.record
    );
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

  get allCardClass() {
    const base = "summary-card total-sets clickable";
    return this.selectedObjectType === "All" ? base + " active" : base;
  }

  get summarySetsByObject() {
    return (this.summary.setsByObject || []).map((obj) => ({
      ...obj,
      cardClass:
        this.selectedObjectType === obj.objectType
          ? "summary-card object-count clickable active"
          : "summary-card object-count clickable"
    }));
  }

  get pageSizeOptionsWithSelected() {
    const current = String(this._effectivePageSize);
    return [
      { label: "12", value: "12", selected: current === "12" },
      { label: "24", value: "24", selected: current === "24" },
      { label: "48", value: "48", selected: current === "48" }
    ];
  }

  get pageSizeOptions() {
    return [
      { label: "12", value: "12" },
      { label: "24", value: "24" },
      { label: "48", value: "48" }
    ];
  }

  get currentPageSizeString() {
    return String(this._effectivePageSize);
  }

  get showEmptyState() {
    return (
      !this.isLoading &&
      !this.error &&
      this.duplicateSets.length === 0 &&
      !this.searchTerm &&
      !this.hasActiveFilters
    );
  }

  get showDuplicatesSection() {
    return !this.error && !this.showEmptyState;
  }

  get showGridContent() {
    return this.duplicateSets.length > 0;
  }

  get showGridLoading() {
    return this.isLoading;
  }

  get showNoSearchResults() {
    return (
      !this.isLoading &&
      (this.searchTerm || this.hasActiveFilters) &&
      this.duplicateSets.length === 0
    );
  }

  get noResultsMessage() {
    if (this.searchTerm && this.hasActiveFilters) {
      return `No duplicate sets match your search "${this.searchTerm}" and filters`;
    }
    if (this.searchTerm) {
      return `No duplicate sets match your search "${this.searchTerm}"`;
    }
    return "No duplicate sets match your filters";
  }

  get totalPages() {
    return Math.ceil(this.totalCount / this._effectivePageSize) || 1;
  }

  get showPagination() {
    return this.totalPages > 1;
  }

  get showBottomPagination() {
    return this.showDuplicatesSection && this.showPagination;
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

  get displayedCount() {
    return this.duplicateSets.length;
  }

  // =========================================================================
  // EVENT HANDLERS
  // =========================================================================

  handlePageSizeChange(event) {
    this._effectivePageSize = parseInt(event.detail.value, 10);
    this.currentPage = 1;
    this.isLoading = true;
    this.loadAllData();
  }

  handlePageSizeSelectChange(event) {
    this._effectivePageSize = parseInt(event.target.value, 10);
    this.currentPage = 1;
    this.isLoading = true;
    this.loadAllData();
  }

  handleObjectTypeChange(event) {
    this.selectedObjectType = event.detail.value;
    this.currentPage = 1;
    this.activeFilters = {};
    this.isLoading = true;
    this.loadFilterFields();
    this.loadAllData();
  }

  // =========================================================================
  // FILTER METHODS
  // =========================================================================

  async loadFilterFields() {
    if (!this.selectedObjectType || this.selectedObjectType === "All") {
      this.filterFields = [];
      return;
    }

    try {
      const fields = await getFilterFields({
        objectType: this.selectedObjectType
      });
      this.filterFields = (fields || []).map((f) => ({
        ...f,
        isPicklist:
          f.fieldType === "PICKLIST" || f.fieldType === "MULTIPICKLIST",
        picklistOptions: f.picklistValues
          ? [
              { label: "All", value: "" },
              ...f.picklistValues.map((v) => ({ label: v, value: v }))
            ]
          : []
      }));
    } catch (err) {
      console.error("Error loading filter fields:", err);
      this.filterFields = [];
    }
  }

  handleFilterChange(event) {
    const fieldName = event.target.dataset.field;
    const value = event.detail ? event.detail.value : event.target.value;

    if (value) {
      this.activeFilters = { ...this.activeFilters, [fieldName]: value };
    } else {
      const updated = { ...this.activeFilters };
      delete updated[fieldName];
      this.activeFilters = updated;
    }

    this.currentPage = 1;
    this.isLoading = true;
    this.loadAllData();
  }

  handleClearFilters() {
    this.activeFilters = {};
    this.template.querySelectorAll(".filter-input").forEach((input) => {
      input.value = "";
    });
    this.currentPage = 1;
    this.isLoading = true;
    this.loadAllData();
  }

  buildFilterCriteria() {
    const entries = Object.entries(this.activeFilters);
    if (entries.length === 0) return null;

    const criteria = entries.map(([field, value]) => ({ field, value }));
    return JSON.stringify(criteria);
  }

  get hasFilterFields() {
    return this.filterFields.length > 0;
  }

  get hasActiveFilters() {
    return Object.keys(this.activeFilters).length > 0;
  }

  handleSummaryCardClick(event) {
    const objectType = event.currentTarget.dataset.object;
    if (objectType) {
      this.selectedObjectType = objectType;
      this.currentPage = 1;
      this.isLoading = true;
      this.loadFilterFields();
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

  // =========================================================================
  // SETTINGS METHODS
  // =========================================================================

  handleOpenSettings() {
    this.showSettings = true;
  }

  handleCloseSettings() {
    this.showSettings = false;
  }

  async handleSettingsSave() {
    this.showSettings = false;
    this.isLoading = true;
    this.loadFilterFields();
    await this.loadAllData();
  }

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
