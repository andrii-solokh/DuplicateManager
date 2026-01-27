import { LightningElement, track } from "lwc";
import getObjectTypeOptions from "@salesforce/apex/DuplicateViewerController.getObjectTypeOptions";
import getAvailableFields from "@salesforce/apex/DuplicateViewerConfigController.getAvailableFields";
import getFieldConfig from "@salesforce/apex/DuplicateViewerConfigController.getFieldConfig";
import saveFieldConfig from "@salesforce/apex/DuplicateViewerConfigController.saveFieldConfig";
import deleteFieldConfig from "@salesforce/apex/DuplicateViewerConfigController.deleteFieldConfig";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class DuplicateViewerSettings extends LightningElement {
  @track objectTypeOptions = [];
  @track selectedObjectType = "";
  @track availableFields = [];
  @track configuredFields = [];
  @track isLoading = false;
  @track isSaving = false;
  @track hasChanges = false;
  @track fieldSearchTerm = "";
  @track objectSearchTerm = "";
  _draggedFieldApiName = null;

  _hasFocused = false;

  connectedCallback() {
    this.loadObjectTypes();
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

  async loadObjectTypes() {
    try {
      const options = await getObjectTypeOptions();
      // Filter out "All" option
      this.objectTypeOptions = (options || [])
        .filter((opt) => opt.value !== "All")
        .map((opt) => ({
          label: opt.label,
          value: opt.value
        }));
    } catch (err) {
      this.showToast("Error", this.extractErrorMessage(err), "error");
    }
  }

  async handleObjectTypeChange(event) {
    const value = event.currentTarget.dataset.value;
    if (!value || value === this.selectedObjectType) return;
    this.selectedObjectType = value;
    this.hasChanges = false;
    this.fieldSearchTerm = "";
    await this.loadFieldData();
  }

  handleObjectSearchChange(event) {
    this.objectSearchTerm = event.target.value || "";
  }

  get filteredObjectTypes() {
    const term = (this.objectSearchTerm || "").toLowerCase();
    return this.objectTypeOptions
      .filter(
        (opt) =>
          !term ||
          opt.label.toLowerCase().includes(term) ||
          opt.value.toLowerCase().includes(term)
      )
      .map((opt) => ({
        ...opt,
        itemClass:
          "sidebar-item" +
          (opt.value === this.selectedObjectType ? " active" : "")
      }));
  }

  async loadFieldData() {
    if (!this.selectedObjectType) return;

    this.isLoading = true;
    try {
      const [fields, configs] = await Promise.all([
        getAvailableFields({ objectType: this.selectedObjectType }),
        getFieldConfig({ objectType: this.selectedObjectType })
      ]);

      // Build a map of existing configs
      const configMap = {};
      (configs || []).forEach((c) => {
        configMap[c.fieldApiName] = c;
      });

      // Merge available fields with existing config
      this.availableFields = (fields || []).map((field) => {
        const existing = configMap[field.apiName];
        const showInPreview = existing ? existing.showInPreview : false;
        const showAsFilter = existing ? existing.showAsFilter : false;
        const isDraggable = showInPreview || showAsFilter;
        return {
          apiName: field.apiName,
          label: field.label,
          fieldType: field.fieldType,
          isFilterable: field.isFilterable,
          showInPreview: showInPreview,
          showAsFilter: showAsFilter,
          sortOrder: existing ? existing.sortOrder : 0,
          configId: existing ? existing.id : null,
          isConfigured: !!existing,
          isDraggable: isDraggable,
          draggableAttr: isDraggable ? "true" : null,
          rowClass: isDraggable ? "draggable-row" : ""
        };
      });

      // Sort: configured fields first (by sortOrder), then unconfigured (by label)
      this.availableFields.sort((a, b) => {
        if (a.isConfigured && !b.isConfigured) return -1;
        if (!a.isConfigured && b.isConfigured) return 1;
        if (a.isConfigured && b.isConfigured) return a.sortOrder - b.sortOrder;
        return a.label.localeCompare(b.label);
      });

      this.configuredFields = configs || [];
    } catch (err) {
      this.showToast("Error", this.extractErrorMessage(err), "error");
    } finally {
      this.isLoading = false;
    }
  }

  handlePreviewChange(event) {
    const apiName = event.target.dataset.field;
    const checked = event.target.checked;
    this.availableFields = this.availableFields.map((f) => {
      if (f.apiName !== apiName) return f;
      const updated = { ...f, showInPreview: checked };
      const isDraggable = updated.showInPreview || updated.showAsFilter;
      updated.isDraggable = isDraggable;
      updated.draggableAttr = isDraggable ? "true" : null;
      updated.rowClass = isDraggable ? "draggable-row" : "";
      return updated;
    });
    this.hasChanges = true;
  }

  handleFilterChange(event) {
    const apiName = event.target.dataset.field;
    const checked = event.target.checked;
    this.availableFields = this.availableFields.map((f) => {
      if (f.apiName !== apiName) return f;
      const updated = { ...f, showAsFilter: checked };
      const isDraggable = updated.showInPreview || updated.showAsFilter;
      updated.isDraggable = isDraggable;
      updated.draggableAttr = isDraggable ? "true" : null;
      updated.rowClass = isDraggable ? "draggable-row" : "";
      return updated;
    });
    this.hasChanges = true;
  }

  handleFieldSearchChange(event) {
    this.fieldSearchTerm = event.target.value || "";
  }

  get filteredAvailableFields() {
    if (!this.fieldSearchTerm) {
      return this.availableFields;
    }
    const term = this.fieldSearchTerm.toLowerCase();
    // Disable drag when searching
    return this.availableFields
      .filter(
        (f) =>
          f.label.toLowerCase().includes(term) ||
          f.apiName.toLowerCase().includes(term)
      )
      .map((f) => ({
        ...f,
        isDraggable: false,
        draggableAttr: null,
        rowClass: ""
      }));
  }

  get isSearchActive() {
    return !!this.fieldSearchTerm;
  }

  get filteredFieldCount() {
    return this.filteredAvailableFields.length;
  }

  get totalFieldCount() {
    return this.availableFields.length;
  }

  get searchCountMessage() {
    return `Showing ${this.filteredFieldCount} of ${this.totalFieldCount} fields`;
  }

  // Drag-and-drop handlers
  handleDragStart(event) {
    this._draggedFieldApiName = event.currentTarget.dataset.field;
    event.currentTarget.classList.add("dragging");
    event.dataTransfer.effectAllowed = "move";
  }

  handleDragOver(event) {
    event.preventDefault();
    event.dataTransfer.dropEffect = "move";
  }

  handleDragEnter(event) {
    event.preventDefault();
    const row = event.currentTarget;
    const targetField = row.dataset.field;
    // Only show drag-over for draggable rows
    const field = this.availableFields.find((f) => f.apiName === targetField);
    if (
      field &&
      field.isDraggable &&
      targetField !== this._draggedFieldApiName
    ) {
      row.classList.add("drag-over");
    }
  }

  handleDragLeave(event) {
    event.currentTarget.classList.remove("drag-over");
  }

  handleDrop(event) {
    event.preventDefault();
    event.currentTarget.classList.remove("drag-over");

    const targetApiName = event.currentTarget.dataset.field;
    const sourceApiName = this._draggedFieldApiName;

    if (!sourceApiName || sourceApiName === targetApiName) {
      return;
    }

    // Only allow drop on draggable fields
    const targetField = this.availableFields.find(
      (f) => f.apiName === targetApiName
    );
    if (!targetField || !targetField.isDraggable) {
      return;
    }

    // Reorder: remove source, insert at target position
    const fields = [...this.availableFields];
    const sourceIndex = fields.findIndex((f) => f.apiName === sourceApiName);
    const targetIndex = fields.findIndex((f) => f.apiName === targetApiName);

    if (sourceIndex === -1 || targetIndex === -1) {
      return;
    }

    const [moved] = fields.splice(sourceIndex, 1);
    fields.splice(targetIndex, 0, moved);

    // Reassign sequential sortOrder for configured fields
    let order = 1;
    this.availableFields = fields.map((f) => {
      if (f.showInPreview || f.showAsFilter) {
        return { ...f, sortOrder: order++ };
      }
      return { ...f, sortOrder: 0 };
    });

    this.hasChanges = true;
  }

  handleDragEnd(event) {
    event.currentTarget.classList.remove("dragging");
    // Clean up any lingering drag-over classes
    const rows = this.template.querySelectorAll("tr.drag-over");
    rows.forEach((r) => r.classList.remove("drag-over"));
    this._draggedFieldApiName = null;
  }

  async handleSave() {
    // Build config array from fields that have preview or filter enabled
    const configsToSave = this.availableFields
      .filter((f) => f.showInPreview || f.showAsFilter)
      .map((f) => ({
        id: f.configId || null,
        fieldApiName: f.apiName,
        sortOrder: f.sortOrder,
        showInPreview: f.showInPreview,
        showAsFilter: f.showAsFilter
      }));

    this.isSaving = true;
    try {
      await saveFieldConfig({
        objectType: this.selectedObjectType,
        configJson: JSON.stringify(configsToSave)
      });

      this.showToast(
        "Success",
        "Field configuration saved successfully.",
        "success"
      );
      this.hasChanges = false;

      // Reload to get updated IDs
      await this.loadFieldData();

      // Notify parent to reload
      this.dispatchEvent(new CustomEvent("save"));
    } catch (err) {
      this.showToast("Error", this.extractErrorMessage(err), "error");
    } finally {
      this.isSaving = false;
    }
  }

  async handleReset() {
    if (!this.selectedObjectType) return;

    this.isSaving = true;
    try {
      await deleteFieldConfig({ objectType: this.selectedObjectType });
      this.showToast(
        "Success",
        `Configuration reset for ${this.selectedObjectType}. Default fields will be used.`,
        "success"
      );
      this.hasChanges = false;
      await this.loadFieldData();
      this.dispatchEvent(new CustomEvent("save"));
    } catch (err) {
      this.showToast("Error", this.extractErrorMessage(err), "error");
    } finally {
      this.isSaving = false;
    }
  }

  handleClose() {
    this.dispatchEvent(new CustomEvent("close"));
  }

  // Computed
  get hasObjectSelected() {
    return !!this.selectedObjectType;
  }

  get hasFields() {
    return this.availableFields.length > 0;
  }

  get configuredCount() {
    return this.availableFields.filter((f) => f.showInPreview || f.showAsFilter)
      .length;
  }

  get saveDisabled() {
    return this.isSaving || !this.hasChanges;
  }

  get resetDisabled() {
    return this.isSaving || !this.selectedObjectType;
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
