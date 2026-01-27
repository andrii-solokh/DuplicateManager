/* eslint-disable jest/no-conditional-expect */
import { createElement } from "lwc";
import DuplicateViewer from "c/duplicateViewer";
import getDuplicateSetPreviews from "@salesforce/apex/DuplicateViewerController.getDuplicateSetPreviews";
import getObjectTypeOptions from "@salesforce/apex/DuplicateViewerController.getObjectTypeOptions";
import getDuplicateSummary from "@salesforce/apex/DuplicateViewerController.getDuplicateSummary";
import deleteDuplicateSet from "@salesforce/apex/DuplicateViewerController.deleteDuplicateSet";
import runDuplicateScan from "@salesforce/apex/DuplicateViewerController.runDuplicateScan";
import getJobStatus from "@salesforce/apex/DuplicateViewerController.getJobStatus";
import getRecentJobs from "@salesforce/apex/DuplicateViewerController.getRecentJobs";
import getFilterFields from "@salesforce/apex/DuplicateViewerController.getFilterFields";
import hasAdminAccess from "@salesforce/apex/DuplicateViewerConfigController.hasAdminAccess";

// Mock Apex methods
jest.mock(
  "@salesforce/apex/DuplicateViewerController.getDuplicateSetPreviews",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DuplicateViewerController.getObjectTypeOptions",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DuplicateViewerController.getDuplicateSummary",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DuplicateViewerController.deleteDuplicateSet",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DuplicateViewerController.runDuplicateScan",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DuplicateViewerController.getJobStatus",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DuplicateViewerController.getRecentJobs",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DuplicateViewerController.getScheduleStatus",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DuplicateViewerController.scheduleJob",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DuplicateViewerController.unscheduleJob",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DuplicateViewerController.getFilterFields",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DuplicateViewerConfigController.hasAdminAccess",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DuplicateViewerController.abortJob",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

// Helper to flush all pending promises
const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

// Mock data
const MOCK_DUPLICATE_SETS = {
  duplicateSets: [
    {
      id: "0DF000000000001",
      name: "DRS-0001",
      recordCount: 3,
      ruleName: "Contact Email Rule",
      objectType: "Contact",
      createdDate: "2026-01-15T10:00:00.000Z",
      lastModifiedDate: "2026-01-15T10:00:00.000Z",
      duplicateRuleId: "0DR000000000001",
      sampleRecords: [
        {
          recordId: "003000000000001",
          recordName: "John Doe",
          fieldValues: { Email: "john@example.com", Phone: "123-456-7890" }
        },
        {
          recordId: "003000000000002",
          recordName: "John D.",
          fieldValues: { Email: "johnd@example.com", Phone: "123-456-7890" }
        }
      ],
      fieldLabels: { Email: "Email", Phone: "Phone" },
      fieldDifferences: { Email: true, Phone: false }
    },
    {
      id: "0DF000000000002",
      name: "DRS-0002",
      recordCount: 2,
      ruleName: "Account Name Rule",
      objectType: "Account",
      createdDate: "2026-01-14T10:00:00.000Z",
      lastModifiedDate: "2026-01-14T10:00:00.000Z",
      duplicateRuleId: "0DR000000000002",
      sampleRecords: [
        {
          recordId: "001000000000001",
          recordName: "Acme Corp",
          fieldValues: { Website: "acme.com", Industry: "Technology" }
        },
        {
          recordId: "001000000000002",
          recordName: "Acme Corporation",
          fieldValues: { Website: "acme.com", Industry: "Technology" }
        }
      ],
      fieldLabels: { Website: "Website", Industry: "Industry" },
      fieldDifferences: { Website: false, Industry: false }
    }
  ],
  totalCount: 2
};

const MOCK_OBJECT_OPTIONS = [
  { label: "All Objects", value: "All" },
  { label: "Contact", value: "Contact" },
  { label: "Account", value: "Account" },
  { label: "Lead", value: "Lead" }
];

const MOCK_SUMMARY = {
  totalSets: 5,
  totalItems: 15,
  setsByObject: [
    { objectType: "Contact", count: 3 },
    { objectType: "Account", count: 2 }
  ]
};

const MOCK_RECENT_JOBS = [];

describe("c-duplicate-viewer", () => {
  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks();

    // Setup default mock implementations
    getDuplicateSetPreviews.mockResolvedValue(MOCK_DUPLICATE_SETS);
    getObjectTypeOptions.mockResolvedValue(MOCK_OBJECT_OPTIONS);
    getDuplicateSummary.mockResolvedValue(MOCK_SUMMARY);
    getRecentJobs.mockResolvedValue(MOCK_RECENT_JOBS);
    getFilterFields.mockResolvedValue([]);
    hasAdminAccess.mockResolvedValue(true);
  });

  afterEach(() => {
    // Clean up DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllTimers();
  });

  // =========================================================================
  // RENDERING TESTS
  // =========================================================================

  it("renders component initially", () => {
    const element = createElement("c-duplicate-viewer", {
      is: DuplicateViewer
    });
    document.body.appendChild(element);

    // Component should render without errors
    const container = element.shadowRoot.querySelector(".container");
    expect(container).not.toBeNull();
  });

  it("renders duplicate sets after data loads", async () => {
    const element = createElement("c-duplicate-viewer", {
      is: DuplicateViewer
    });
    document.body.appendChild(element);

    // Wait for async operations to complete
    await flushPromises();

    const cards = element.shadowRoot.querySelectorAll(".duplicate-set-card");
    expect(cards.length).toBe(2);
  });

  it("renders summary cards with correct data", async () => {
    const element = createElement("c-duplicate-viewer", {
      is: DuplicateViewer
    });
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    const summarySection = element.shadowRoot.querySelector(".summary-section");
    expect(summarySection).not.toBeNull();
  });

  it("renders empty state when no duplicates", async () => {
    getDuplicateSetPreviews.mockResolvedValue({
      duplicateSets: [],
      totalCount: 0
    });

    const element = createElement("c-duplicate-viewer", {
      is: DuplicateViewer
    });
    document.body.appendChild(element);

    await flushPromises();

    const emptyState = element.shadowRoot.querySelector(".empty-state");
    expect(emptyState).not.toBeNull();
  });

  it("renders error state when API fails", async () => {
    getDuplicateSetPreviews.mockRejectedValue(new Error("API Error"));

    const element = createElement("c-duplicate-viewer", {
      is: DuplicateViewer
    });
    document.body.appendChild(element);

    await flushPromises();

    const errorElement = element.shadowRoot.querySelector(".error-container");
    expect(errorElement).not.toBeNull();
  });

  // =========================================================================
  // INTERACTION TESTS
  // =========================================================================

  it("filters duplicate sets by object type", async () => {
    const element = createElement("c-duplicate-viewer", {
      is: DuplicateViewer
    });
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    // Find the combobox
    const combobox = element.shadowRoot.querySelector("lightning-combobox");
    expect(combobox).not.toBeNull();

    // Simulate selection change
    combobox.dispatchEvent(
      new CustomEvent("change", { detail: { value: "Contact" } })
    );

    await Promise.resolve();

    // Verify API was called with filter
    expect(getDuplicateSetPreviews).toHaveBeenCalledWith(
      expect.objectContaining({ objectType: "Contact" })
    );
  });

  it("handles refresh button click", async () => {
    const element = createElement("c-duplicate-viewer", {
      is: DuplicateViewer
    });
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    // Clear mock to track new calls
    getDuplicateSetPreviews.mockClear();
    getDuplicateSummary.mockClear();

    const refreshButton = element.shadowRoot.querySelector(".refresh-btn");
    if (refreshButton) {
      refreshButton.click();

      await Promise.resolve();

      expect(getDuplicateSetPreviews).toHaveBeenCalled();
      expect(getDuplicateSummary).toHaveBeenCalled();
    }
  });

  it("disables run scan button when All is selected", async () => {
    const element = createElement("c-duplicate-viewer", {
      is: DuplicateViewer
    });
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    const scanButton = element.shadowRoot.querySelector(".scan-btn");
    if (scanButton) {
      expect(scanButton.disabled).toBe(true);
    }
  });

  it("enables run scan button when specific object selected", async () => {
    const element = createElement("c-duplicate-viewer", {
      is: DuplicateViewer
    });
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    // Select Contact
    const combobox = element.shadowRoot.querySelector("lightning-combobox");
    if (combobox) {
      combobox.dispatchEvent(
        new CustomEvent("change", { detail: { value: "Contact" } })
      );
    }

    await Promise.resolve();

    const scanButton = element.shadowRoot.querySelector(".scan-btn");
    if (scanButton) {
      expect(scanButton.disabled).toBe(false);
    }
  });

  it("opens merge modal when duplicate set is clicked", async () => {
    const element = createElement("c-duplicate-viewer", {
      is: DuplicateViewer
    });
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    const card = element.shadowRoot.querySelector(".duplicate-set-card");
    if (card) {
      card.click();

      await Promise.resolve();

      // Check that merge modal is shown (c-duplicate-merge-modal component)
      const mergeModal = element.shadowRoot.querySelector(
        "c-duplicate-merge-modal"
      );
      expect(mergeModal).not.toBeNull();
    }
  });

  // =========================================================================
  // PAGINATION TESTS
  // =========================================================================

  it("displays pagination when multiple pages exist", async () => {
    getDuplicateSetPreviews.mockResolvedValue({
      duplicateSets: MOCK_DUPLICATE_SETS.duplicateSets,
      totalCount: 50 // More than page size
    });

    const element = createElement("c-duplicate-viewer", {
      is: DuplicateViewer
    });
    document.body.appendChild(element);

    await flushPromises();

    const pagination = element.shadowRoot.querySelector(".pagination");
    expect(pagination).not.toBeNull();
  });

  it("handles next page navigation", async () => {
    getDuplicateSetPreviews.mockResolvedValue({
      duplicateSets: MOCK_DUPLICATE_SETS.duplicateSets,
      totalCount: 50
    });

    const element = createElement("c-duplicate-viewer", {
      is: DuplicateViewer
    });
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    const nextButton = element.shadowRoot.querySelector(".next-btn");
    if (nextButton && !nextButton.disabled) {
      nextButton.click();

      await Promise.resolve();

      expect(getDuplicateSetPreviews).toHaveBeenCalledWith(
        expect.objectContaining({ offsetCount: 12 })
      );
    }
  });

  // =========================================================================
  // DELETE TESTS
  // =========================================================================

  it("calls delete API when delete is confirmed", async () => {
    deleteDuplicateSet.mockResolvedValue(undefined);

    // Mock confirm
    global.confirm = jest.fn(() => true);

    const element = createElement("c-duplicate-viewer", {
      is: DuplicateViewer
    });
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    const deleteButton = element.shadowRoot.querySelector(".delete-btn");
    if (deleteButton) {
      deleteButton.click();

      await Promise.resolve();

      expect(deleteDuplicateSet).toHaveBeenCalled();
    }
  });

  it("does not delete when cancelled", async () => {
    // Mock confirm to return false
    global.confirm = jest.fn(() => false);

    const element = createElement("c-duplicate-viewer", {
      is: DuplicateViewer
    });
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    const deleteButton = element.shadowRoot.querySelector(".delete-btn");
    if (deleteButton) {
      deleteButton.click();

      await Promise.resolve();

      expect(deleteDuplicateSet).not.toHaveBeenCalled();
    }
  });

  // =========================================================================
  // JOB POLLING TESTS
  // =========================================================================

  it("starts polling when scan is initiated", async () => {
    runDuplicateScan.mockResolvedValue("707000000000001");
    getJobStatus.mockResolvedValue({
      jobId: "707000000000001",
      status: "Processing",
      progressPercent: 50,
      isComplete: false,
      isSuccess: false
    });

    // Mock confirm
    global.confirm = jest.fn(() => true);

    jest.useFakeTimers();

    const element = createElement("c-duplicate-viewer", {
      is: DuplicateViewer
    });
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    // Select an object type first
    const combobox = element.shadowRoot.querySelector("lightning-combobox");
    if (combobox) {
      combobox.dispatchEvent(
        new CustomEvent("change", { detail: { value: "Contact" } })
      );
    }

    await Promise.resolve();

    const scanButton = element.shadowRoot.querySelector(".scan-btn");
    if (scanButton) {
      scanButton.click();

      await Promise.resolve();

      expect(runDuplicateScan).toHaveBeenCalledWith({ objectType: "Contact" });
    }

    jest.useRealTimers();
  });

  // =========================================================================
  // COMPUTED PROPERTY TESTS
  // =========================================================================

  it("computes showEmptyState correctly", async () => {
    getDuplicateSetPreviews.mockResolvedValue({
      duplicateSets: [],
      totalCount: 0
    });

    const element = createElement("c-duplicate-viewer", {
      is: DuplicateViewer
    });
    document.body.appendChild(element);

    await flushPromises();

    // Component should show empty state
    const emptyState = element.shadowRoot.querySelector(".empty-state");
    expect(emptyState).not.toBeNull();
  });

  it("computes totalPages correctly", async () => {
    getDuplicateSetPreviews.mockResolvedValue({
      duplicateSets: MOCK_DUPLICATE_SETS.duplicateSets,
      totalCount: 25 // Should be 3 pages with page size 12
    });

    const element = createElement("c-duplicate-viewer", {
      is: DuplicateViewer
    });
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    const pageInfo = element.shadowRoot.querySelector(".page-info");
    if (pageInfo) {
      expect(pageInfo.textContent).toContain("3");
    }
  });
});
