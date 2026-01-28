import { createElement } from "lwc";
import DuplicateViewerSettings from "c/duplicateViewerSettings";
import getObjectTypeOptions from "@salesforce/apex/DuplicateViewerController.getObjectTypeOptions";
import getAvailableFields from "@salesforce/apex/DuplicateViewerConfigController.getAvailableFields";
import getFieldConfig from "@salesforce/apex/DuplicateViewerConfigController.getFieldConfig";
import saveFieldConfig from "@salesforce/apex/DuplicateViewerConfigController.saveFieldConfig";
import deleteFieldConfig from "@salesforce/apex/DuplicateViewerConfigController.deleteFieldConfig";

// Mock Apex methods
jest.mock(
  "@salesforce/apex/DuplicateViewerController.getObjectTypeOptions",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DuplicateViewerConfigController.getAvailableFields",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DuplicateViewerConfigController.getFieldConfig",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DuplicateViewerConfigController.saveFieldConfig",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DuplicateViewerConfigController.deleteFieldConfig",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

const MOCK_OBJECT_OPTIONS = [
  { label: "Contact", value: "Contact" },
  { label: "Account", value: "Account" }
];

const MOCK_AVAILABLE_FIELDS = [
  {
    apiName: "Email",
    label: "Email",
    fieldType: "EMAIL",
    isFilterable: true
  },
  {
    apiName: "Phone",
    label: "Phone",
    fieldType: "PHONE",
    isFilterable: true
  },
  {
    apiName: "Title",
    label: "Title",
    fieldType: "STRING",
    isFilterable: true
  }
];

describe("c-duplicate-viewer-settings", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    getObjectTypeOptions.mockResolvedValue(MOCK_OBJECT_OPTIONS);
    getAvailableFields.mockResolvedValue(MOCK_AVAILABLE_FIELDS);
    getFieldConfig.mockResolvedValue([]);
    saveFieldConfig.mockResolvedValue(undefined);
    deleteFieldConfig.mockResolvedValue(undefined);
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders the settings modal", () => {
    const element = createElement("c-duplicate-viewer-settings", {
      is: DuplicateViewerSettings
    });
    document.body.appendChild(element);

    const modal = element.shadowRoot.querySelector(".slds-modal");
    expect(modal).not.toBeNull();
  });

  it("loads object types on init", async () => {
    const element = createElement("c-duplicate-viewer-settings", {
      is: DuplicateViewerSettings
    });
    document.body.appendChild(element);

    await flushPromises();

    expect(getObjectTypeOptions).toHaveBeenCalled();
  });

  it("auto-selects the first object on load", async () => {
    const element = createElement("c-duplicate-viewer-settings", {
      is: DuplicateViewerSettings
    });
    document.body.appendChild(element);

    await flushPromises();

    // First object should be auto-selected, so field data should load
    expect(getAvailableFields).toHaveBeenCalled();
    // Placeholder should not be shown
    const placeholder = element.shadowRoot.querySelector(
      ".settings-placeholder"
    );
    expect(placeholder).toBeNull();
  });

  it("loads fields when object type is selected from sidebar", async () => {
    const element = createElement("c-duplicate-viewer-settings", {
      is: DuplicateViewerSettings
    });
    document.body.appendChild(element);

    await flushPromises();

    // Sidebar items should be rendered
    const sidebarItems = element.shadowRoot.querySelectorAll(".sidebar-item");
    expect(sidebarItems.length).toBeGreaterThan(0);

    // Click the first sidebar item (Contact)
    const contactItem = Array.from(sidebarItems).find(
      (item) => item.dataset.value === "Contact"
    );
    expect(contactItem).toBeTruthy();
    contactItem.click();

    await flushPromises();

    expect(getAvailableFields).toHaveBeenCalledWith({
      objectType: "Contact"
    });
    expect(getFieldConfig).toHaveBeenCalledWith({
      objectType: "Contact"
    });
  });

  it("dispatches close event on cancel", async () => {
    const element = createElement("c-duplicate-viewer-settings", {
      is: DuplicateViewerSettings
    });

    const handler = jest.fn();
    element.addEventListener("close", handler);

    document.body.appendChild(element);

    await flushPromises();

    // Find all lightning-button elements and find the Cancel one
    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    const cancelButton = Array.from(buttons).find(
      (btn) => btn.label === "Cancel"
    );
    expect(cancelButton).toBeTruthy();
    cancelButton.click();
    expect(handler).toHaveBeenCalled();
  });

  it("dispatches close event on X button", async () => {
    const element = createElement("c-duplicate-viewer-settings", {
      is: DuplicateViewerSettings
    });

    const handler = jest.fn();
    element.addEventListener("close", handler);

    document.body.appendChild(element);

    await flushPromises();

    const closeButton = element.shadowRoot.querySelector(
      "button.slds-modal__close"
    );
    expect(closeButton).toBeTruthy();
    closeButton.click();
    expect(handler).toHaveBeenCalled();
  });
});
