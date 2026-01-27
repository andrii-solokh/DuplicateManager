import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from "lightning/navigation";
import getRecordComparison from "@salesforce/apex/DuplicateMergeController.getRecordComparison";
import mergeRecords from "@salesforce/apex/DuplicateMergeController.mergeRecords";
import deleteDuplicateSet from "@salesforce/apex/DuplicateViewerController.deleteDuplicateSet";

export default class DuplicateMergeModal extends NavigationMixin(
  LightningElement
) {
  @api duplicateSetId;

  @track isLoading = true;
  @track isMerging = false;
  @track error = null;
  @track mergeSuccess = false;
  @track mergeResult = null;

  @track records = [];
  @track fields = [];
  @track masterRecordId = null;
  @track fieldSelections = {}; // Map of fieldApiName -> recordId

  // Filter state
  @track searchTerm = "";
  @track showDifferences = true;
  @track showSame = false;
  @track showEmpty = false;

  // Stats
  @track differenceCount = 0;
  @track sameCount = 0;
  @track emptyCount = 0;

  // =========================================================================
  // LIFECYCLE
  // =========================================================================

  _hasFocused = false;

  connectedCallback() {
    this.loadComparison();
  }

  renderedCallback() {
    if (!this._hasFocused) {
      this._hasFocused = true;
      const dialog = this.template.querySelector('section[role="dialog"]');
      if (dialog) {
        dialog.focus();
      }
    }
  }

  handleKeyDown(event) {
    if (event.key === "Escape") {
      this.handleClose();
    }
  }

  // =========================================================================
  // DATA LOADING
  // =========================================================================

  async loadComparison() {
    this.isLoading = true;
    this.error = null;

    try {
      const result = await getRecordComparison({
        duplicateSetId: this.duplicateSetId
      });

      // Process records
      this.records = result.records.map((record, index) => ({
        ...record,
        isMaster: index === 0,
        cardClass: index === 0 ? "master-card selected" : "master-card"
      }));

      // Set first record as master by default
      if (this.records.length > 0) {
        this.masterRecordId = this.records[0].recordId;
      }

      // Process fields and set initial selections
      this.fields = result.fields.map((field) => ({
        ...field,
        values: field.values.map((value) => ({
          ...value,
          isSelected: value.recordId === this.masterRecordId,
          cellClass: this.getCellClass(
            value,
            field,
            value.recordId === this.masterRecordId
          )
        }))
      }));

      // Initialize field selections to master record values
      this.fieldSelections = {};
      for (const field of this.fields) {
        this.fieldSelections[field.apiName] = this.masterRecordId;
      }

      // Calculate stats
      this.calculateStats();
    } catch (err) {
      this.error = this.extractErrorMessage(err);
    } finally {
      this.isLoading = false;
    }
  }

  calculateStats() {
    this.differenceCount = this.fields.filter((f) => f.hasDifference).length;
    this.sameCount = this.fields.filter((f) => f.allSame && !f.allEmpty).length;
    this.emptyCount = this.fields.filter((f) => f.allEmpty).length;
  }

  // =========================================================================
  // COMPUTED PROPERTIES
  // =========================================================================

  get filteredFields() {
    return this.fields
      .filter((field) => {
        // Apply visibility filters
        if (field.hasDifference && !this.showDifferences) return false;
        if (field.allSame && !field.allEmpty && !this.showSame) return false;
        if (field.allEmpty && !this.showEmpty) return false;

        // Apply search filter
        if (this.searchTerm) {
          const term = this.searchTerm.toLowerCase();
          const labelMatch = field.label.toLowerCase().includes(term);
          const apiMatch = field.apiName.toLowerCase().includes(term);
          const valueMatch = field.values.some(
            (v) => v.displayValue && v.displayValue.toLowerCase().includes(term)
          );
          if (!labelMatch && !apiMatch && !valueMatch) return false;
        }

        return true;
      })
      .map((field) => ({
        ...field,
        rowClass: this.getRowClass(field),
        values: field.values.map((value) => ({
          ...value,
          isSelected: this.fieldSelections[field.apiName] === value.recordId,
          cellClass: this.getCellClass(
            value,
            field,
            this.fieldSelections[field.apiName] === value.recordId
          )
        }))
      }));
  }

  get visibleFieldCount() {
    return this.filteredFields.length;
  }

  get totalFieldCount() {
    return this.fields.filter((f) => !f.allEmpty).length;
  }

  get noFieldsVisible() {
    return this.filteredFields.length === 0 && this.fields.length > 0;
  }

  get masterRecordName() {
    const master = this.records.find((r) => r.recordId === this.masterRecordId);
    return master ? master.recordName : "";
  }

  get selectedFieldCount() {
    return Object.keys(this.fieldSelections).filter(
      (key) => this.fieldSelections[key] !== this.masterRecordId
    ).length;
  }

  get isMergeDisabled() {
    return !this.masterRecordId || this.records.length < 2 || this.isMerging;
  }

  get mergeButtonLabel() {
    return this.isMerging ? "Merging..." : "Merge Records";
  }

  get differencesButtonVariant() {
    return this.showDifferences ? "brand" : "neutral";
  }

  get sameButtonVariant() {
    return this.showSame ? "brand" : "neutral";
  }

  get emptyButtonVariant() {
    return this.showEmpty ? "brand" : "neutral";
  }

  // =========================================================================
  // EVENT HANDLERS
  // =========================================================================

  handleMasterSelect(event) {
    const recordId = event.currentTarget.dataset.id;
    this.masterRecordId = recordId;

    // Update record cards
    this.records = this.records.map((record) => ({
      ...record,
      isMaster: record.recordId === recordId,
      cardClass:
        record.recordId === recordId ? "master-card selected" : "master-card"
    }));

    // Reset field selections to new master
    for (const field of this.fields) {
      this.fieldSelections[field.apiName] = recordId;
    }

    // Trigger reactivity
    this.fieldSelections = { ...this.fieldSelections };
  }

  handleValueSelect(event) {
    const fieldApiName = event.currentTarget.dataset.field;
    const recordId = event.currentTarget.dataset.record;

    // Find the field
    const field = this.fields.find((f) => f.apiName === fieldApiName);
    if (!field || !field.isUpdateable) {
      return; // Can't select non-updateable fields
    }

    // Update selection
    this.fieldSelections = {
      ...this.fieldSelections,
      [fieldApiName]: recordId
    };
  }

  handleSearchChange(event) {
    this.searchTerm = event.target.value;
  }

  handleShowDifferences() {
    this.showDifferences = !this.showDifferences;
  }

  handleShowSame() {
    this.showSame = !this.showSame;
  }

  handleShowEmpty() {
    this.showEmpty = !this.showEmpty;
  }

  async handleMerge() {
    if (this.isMergeDisabled) return;

    // eslint-disable-next-line no-alert, no-restricted-globals
    const confirmed = confirm(
      `Are you sure you want to merge ${this.records.length - 1} record(s) into "${this.masterRecordName}"?\n\n` +
        "This action cannot be undone. The duplicate records will be deleted."
    );

    if (!confirmed) return;

    this.isMerging = true;

    try {
      // Get duplicate record IDs (all except master)
      const duplicateRecordIds = this.records
        .filter((r) => r.recordId !== this.masterRecordId)
        .map((r) => r.recordId);

      // Filter selections to only include fields where we selected a different record
      const fieldSelectionsToSend = {};
      for (const [fieldName, recordId] of Object.entries(
        this.fieldSelections
      )) {
        if (recordId !== this.masterRecordId) {
          fieldSelectionsToSend[fieldName] = recordId;
        }
      }

      const result = await mergeRecords({
        masterRecordId: this.masterRecordId,
        duplicateRecordIds: duplicateRecordIds,
        fieldSelections: fieldSelectionsToSend,
        duplicateSetId: this.duplicateSetId
      });

      if (result.success) {
        // Show success state in modal
        this.mergeSuccess = true;
        this.mergeResult = {
          ...result,
          recordUrl: `/lightning/r/${result.masterRecordId}/view`
        };

        // Dispatch merge complete event (parent will refresh data)
        this.dispatchEvent(
          new CustomEvent("mergecomplete", {
            detail: {
              masterRecordId: result.masterRecordId,
              mergedCount: result.mergedCount
            }
          })
        );
      }
    } catch (err) {
      this.showToast("Error", this.extractErrorMessage(err), "error");
    } finally {
      this.isMerging = false;
    }
  }

  handleClose() {
    this.dispatchEvent(new CustomEvent("close"));
  }

  async handleDelete() {
    // eslint-disable-next-line no-alert, no-restricted-globals
    if (!confirm("Are you sure you want to delete this duplicate set?")) {
      return;
    }

    try {
      await deleteDuplicateSet({ setId: this.duplicateSetId });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "Duplicate set deleted successfully.",
          variant: "success"
        })
      );
      this.dispatchEvent(new CustomEvent("mergecomplete"));
      this.dispatchEvent(new CustomEvent("close"));
    } catch (err) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: err.body?.message || err.message || "Failed to delete set",
          variant: "error"
        })
      );
    }
  }

  handleNavigateToRecord() {
    if (this.mergeResult && this.mergeResult.masterRecordId) {
      this[NavigationMixin.Navigate]({
        type: "standard__recordPage",
        attributes: {
          recordId: this.mergeResult.masterRecordId,
          actionName: "view"
        }
      });
    }
  }

  // =========================================================================
  // HELPER METHODS
  // =========================================================================

  getRowClass(field) {
    if (field.hasDifference) return "field-row difference";
    if (field.allEmpty) return "field-row empty";
    return "field-row same";
  }

  getCellClass(value, field, isSelected) {
    let classes = ["value-cell"];

    if (isSelected) classes.push("selected");
    if (value.isEmpty) classes.push("empty");
    if (field.isUpdateable) classes.push("selectable");
    if (field.hasDifference && !value.isEmpty) classes.push("highlight");

    return classes.join(" ");
  }

  extractErrorMessage(error) {
    if (typeof error === "string") return error;
    if (error.body && error.body.message) return error.body.message;
    if (error.message) return error.message;
    return "An unknown error occurred.";
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
