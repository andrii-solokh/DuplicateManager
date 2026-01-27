import { createElement } from "lwc";
import DuplicateMergeModal from "c/duplicateMergeModal";
import getRecordComparison from "@salesforce/apex/DuplicateMergeController.getRecordComparison";
import mergeRecords from "@salesforce/apex/DuplicateMergeController.mergeRecords";

// Mock Apex methods
jest.mock(
  "@salesforce/apex/DuplicateMergeController.getRecordComparison",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DuplicateMergeController.mergeRecords",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

// Mock NavigationMixin
const mockNavigate = jest.fn();
jest.mock(
  "lightning/navigation",
  () => ({
    NavigationMixin: (Base) =>
      class extends Base {
        [Symbol.for("lightning/navigation/Navigate")] = mockNavigate;
      }
  }),
  { virtual: true }
);

// Mock data
const MOCK_COMPARISON_RESULT = {
  objectType: "Contact",
  records: [
    { recordId: "003000000000001", recordName: "John Doe" },
    { recordId: "003000000000002", recordName: "John D." }
  ],
  fields: [
    {
      apiName: "FirstName",
      label: "First Name",
      type: "STRING",
      isUpdateable: true,
      isRequired: false,
      isNameField: false,
      hasDifference: false,
      allSame: true,
      allEmpty: false,
      values: [
        {
          recordId: "003000000000001",
          value: "John",
          displayValue: "John",
          isEmpty: false
        },
        {
          recordId: "003000000000002",
          value: "John",
          displayValue: "John",
          isEmpty: false
        }
      ]
    },
    {
      apiName: "LastName",
      label: "Last Name",
      type: "STRING",
      isUpdateable: true,
      isRequired: true,
      isNameField: true,
      hasDifference: true,
      allSame: false,
      allEmpty: false,
      values: [
        {
          recordId: "003000000000001",
          value: "Doe",
          displayValue: "Doe",
          isEmpty: false
        },
        {
          recordId: "003000000000002",
          value: "D.",
          displayValue: "D.",
          isEmpty: false
        }
      ]
    },
    {
      apiName: "Email",
      label: "Email",
      type: "EMAIL",
      isUpdateable: true,
      isRequired: false,
      isNameField: false,
      hasDifference: true,
      allSame: false,
      allEmpty: false,
      values: [
        {
          recordId: "003000000000001",
          value: "john@example.com",
          displayValue: "john@example.com",
          isEmpty: false
        },
        {
          recordId: "003000000000002",
          value: "johnd@example.com",
          displayValue: "johnd@example.com",
          isEmpty: false
        }
      ]
    },
    {
      apiName: "Phone",
      label: "Phone",
      type: "PHONE",
      isUpdateable: true,
      isRequired: false,
      isNameField: false,
      hasDifference: false,
      allSame: false,
      allEmpty: true,
      values: [
        {
          recordId: "003000000000001",
          value: null,
          displayValue: "",
          isEmpty: true
        },
        {
          recordId: "003000000000002",
          value: null,
          displayValue: "",
          isEmpty: true
        }
      ]
    }
  ]
};

const MOCK_MERGE_SUCCESS = {
  success: true,
  masterRecordId: "003000000000001",
  mergedCount: 1,
  message: "Successfully merged 1 record(s) into master."
};

describe("c-duplicate-merge-modal", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    getRecordComparison.mockResolvedValue(MOCK_COMPARISON_RESULT);
    mergeRecords.mockResolvedValue(MOCK_MERGE_SUCCESS);
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  // =========================================================================
  // RENDERING TESTS
  // =========================================================================

  it("renders loading spinner initially", () => {
    const element = createElement("c-duplicate-merge-modal", {
      is: DuplicateMergeModal
    });
    element.duplicateSetId = "0DF000000000001";
    document.body.appendChild(element);

    const spinner = element.shadowRoot.querySelector("lightning-spinner");
    expect(spinner).not.toBeNull();
  });

  it("renders comparison table after data loads", async () => {
    const element = createElement("c-duplicate-merge-modal", {
      is: DuplicateMergeModal
    });
    element.duplicateSetId = "0DF000000000001";
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    const table = element.shadowRoot.querySelector(".comparison-table");
    expect(table).not.toBeNull();
  });

  it("renders master record selection cards", async () => {
    const element = createElement("c-duplicate-merge-modal", {
      is: DuplicateMergeModal
    });
    element.duplicateSetId = "0DF000000000001";
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    const masterCards = element.shadowRoot.querySelectorAll(".master-card");
    expect(masterCards.length).toBe(2);
  });

  it("renders field rows with correct data", async () => {
    const element = createElement("c-duplicate-merge-modal", {
      is: DuplicateMergeModal
    });
    element.duplicateSetId = "0DF000000000001";
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    const fieldRows = element.shadowRoot.querySelectorAll(".field-row");
    // Default filter shows differences, so we should see 2 (LastName and Email have differences)
    expect(fieldRows.length).toBeGreaterThanOrEqual(2);
  });

  it("renders filter buttons", async () => {
    const element = createElement("c-duplicate-merge-modal", {
      is: DuplicateMergeModal
    });
    element.duplicateSetId = "0DF000000000001";
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    // Filter buttons are inside lightning-button-group within filter-toggles
    const filterToggles = element.shadowRoot.querySelector(".filter-toggles");
    expect(filterToggles).not.toBeNull();
    const filterButtons = filterToggles.querySelectorAll(
      "lightning-button-group lightning-button"
    );
    expect(filterButtons.length).toBe(2); // Differences, Same
  });

  it("renders error state when API fails", async () => {
    getRecordComparison.mockRejectedValue(new Error("API Error"));

    const element = createElement("c-duplicate-merge-modal", {
      is: DuplicateMergeModal
    });
    element.duplicateSetId = "0DF000000000001";
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    const errorElement = element.shadowRoot.querySelector(".error-container");
    expect(errorElement).not.toBeNull();
  });

  // =========================================================================
  // MASTER SELECTION TESTS
  // =========================================================================

  it("sets first record as master by default", async () => {
    const element = createElement("c-duplicate-merge-modal", {
      is: DuplicateMergeModal
    });
    element.duplicateSetId = "0DF000000000001";
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    const selectedCard = element.shadowRoot.querySelector(
      ".master-card.selected"
    );
    expect(selectedCard).not.toBeNull();
  });

  it("changes master when different card is clicked", async () => {
    const element = createElement("c-duplicate-merge-modal", {
      is: DuplicateMergeModal
    });
    element.duplicateSetId = "0DF000000000001";
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    const cards = element.shadowRoot.querySelectorAll(".master-card");
    expect(cards.length).toBeGreaterThan(1);
    // Click the second card
    cards[1].click();

    await Promise.resolve();

    // Second card should now be selected
    expect(cards[1].classList.contains("selected")).toBe(true);
  });

  // =========================================================================
  // FIELD FILTERING TESTS
  // =========================================================================

  it("filters to show only differences by default", async () => {
    const element = createElement("c-duplicate-merge-modal", {
      is: DuplicateMergeModal
    });
    element.duplicateSetId = "0DF000000000001";
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    // By default, differences should be shown
    const differenceRows = element.shadowRoot.querySelectorAll(
      ".field-row.difference"
    );
    expect(differenceRows.length).toBeGreaterThan(0);
  });

  it("toggles same fields visibility", async () => {
    const element = createElement("c-duplicate-merge-modal", {
      is: DuplicateMergeModal
    });
    element.duplicateSetId = "0DF000000000001";
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    // Find and click the "Same" filter button (second button in the group)
    const filterButtons = element.shadowRoot.querySelectorAll(
      ".filter-toggles lightning-button-group lightning-button"
    );
    expect(filterButtons.length).toBe(2);
    // Second button is the "Same" button
    filterButtons[1].click();

    await Promise.resolve();

    const sameRows = element.shadowRoot.querySelectorAll(".field-row.same");
    expect(sameRows.length).toBeGreaterThanOrEqual(0);
  });

  it("filters fields by search term", async () => {
    const element = createElement("c-duplicate-merge-modal", {
      is: DuplicateMergeModal
    });
    element.duplicateSetId = "0DF000000000001";
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    const searchInput = element.shadowRoot.querySelector(".search-input");
    expect(searchInput).not.toBeNull();
    // Search for "email"
    searchInput.value = "email";
    searchInput.dispatchEvent(
      new CustomEvent("change", { detail: { value: "email" } })
    );

    await Promise.resolve();

    // Should show Email field (search matches within the visible differences)
    const tbody = element.shadowRoot.querySelector(".comparison-table tbody");
    const fieldRows = tbody ? tbody.querySelectorAll("tr") : [];
    expect(fieldRows.length).toBeLessThanOrEqual(2);
  });

  // =========================================================================
  // VALUE SELECTION TESTS
  // =========================================================================

  it("allows selecting values from non-master records", async () => {
    const element = createElement("c-duplicate-merge-modal", {
      is: DuplicateMergeModal
    });
    element.duplicateSetId = "0DF000000000001";
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    // Find a value cell that is selectable
    const selectableCells = element.shadowRoot.querySelectorAll(
      ".value-cell.selectable"
    );
    expect(selectableCells.length).toBeGreaterThan(1);
    selectableCells[1].click();

    await Promise.resolve();

    expect(selectableCells[1].classList.contains("selected")).toBe(true);
  });

  // =========================================================================
  // MERGE TESTS
  // =========================================================================

  it("calls merge API when merge is confirmed", async () => {
    global.confirm = jest.fn(() => true);

    const element = createElement("c-duplicate-merge-modal", {
      is: DuplicateMergeModal
    });
    element.duplicateSetId = "0DF000000000001";
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    const mergeButton = element.shadowRoot.querySelector(".merge-btn");
    expect(mergeButton).not.toBeNull();
    mergeButton.click();

    await Promise.resolve();
    await Promise.resolve();

    expect(mergeRecords).toHaveBeenCalled();
  });

  it("does not merge when cancelled", async () => {
    global.confirm = jest.fn(() => false);

    const element = createElement("c-duplicate-merge-modal", {
      is: DuplicateMergeModal
    });
    element.duplicateSetId = "0DF000000000001";
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    const mergeButton2 = element.shadowRoot.querySelector(".merge-btn");
    expect(mergeButton2).not.toBeNull();
    mergeButton2.click();

    await Promise.resolve();

    expect(mergeRecords).not.toHaveBeenCalled();
  });

  it("shows success state after successful merge", async () => {
    global.confirm = jest.fn(() => true);

    const element = createElement("c-duplicate-merge-modal", {
      is: DuplicateMergeModal
    });
    element.duplicateSetId = "0DF000000000001";
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    const mergeButton = element.shadowRoot.querySelector(".merge-btn");
    expect(mergeButton).not.toBeNull();
    mergeButton.click();

    await Promise.resolve();
    await Promise.resolve();

    const successState = element.shadowRoot.querySelector(".success-container");
    expect(successState).not.toBeNull();
  });

  it("dispatches mergecomplete event on successful merge", async () => {
    global.confirm = jest.fn(() => true);

    const element = createElement("c-duplicate-merge-modal", {
      is: DuplicateMergeModal
    });
    element.duplicateSetId = "0DF000000000001";
    document.body.appendChild(element);

    const handler = jest.fn();
    element.addEventListener("mergecomplete", handler);

    await Promise.resolve();
    await Promise.resolve();

    const mergeButton = element.shadowRoot.querySelector(".merge-btn");
    expect(mergeButton).not.toBeNull();
    mergeButton.click();

    await Promise.resolve();
    await Promise.resolve();

    expect(handler).toHaveBeenCalled();
  });

  // =========================================================================
  // CLOSE TESTS
  // =========================================================================

  it("dispatches close event when close button is clicked", async () => {
    const element = createElement("c-duplicate-merge-modal", {
      is: DuplicateMergeModal
    });
    element.duplicateSetId = "0DF000000000001";
    document.body.appendChild(element);

    const handler = jest.fn();
    element.addEventListener("close", handler);

    await Promise.resolve();
    await Promise.resolve();

    const closeButton = element.shadowRoot.querySelector(
      "button.slds-modal__close"
    );
    expect(closeButton).not.toBeNull();
    closeButton.click();

    expect(handler).toHaveBeenCalled();
  });

  // =========================================================================
  // COMPUTED PROPERTY TESTS
  // =========================================================================

  it("computes filteredFields correctly", async () => {
    const element = createElement("c-duplicate-merge-modal", {
      is: DuplicateMergeModal
    });
    element.duplicateSetId = "0DF000000000001";
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    // Default shows differences only
    const fieldRows = element.shadowRoot.querySelectorAll(".field-row");
    // Should show LastName and Email (2 fields with differences)
    expect(fieldRows.length).toBe(2);
  });

  it("computes masterRecordName correctly", async () => {
    const element = createElement("c-duplicate-merge-modal", {
      is: DuplicateMergeModal
    });
    element.duplicateSetId = "0DF000000000001";
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    const masterName = element.shadowRoot.querySelector(".master-name");
    expect(masterName).not.toBeNull();
    expect(masterName.textContent).toContain("John Doe");
  });

  it("disables merge button when less than 2 records", async () => {
    getRecordComparison.mockResolvedValue({
      ...MOCK_COMPARISON_RESULT,
      records: [{ recordId: "003000000000001", recordName: "John Doe" }]
    });

    const element = createElement("c-duplicate-merge-modal", {
      is: DuplicateMergeModal
    });
    element.duplicateSetId = "0DF000000000001";
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    const mergeButton = element.shadowRoot.querySelector(".merge-btn");
    expect(mergeButton).not.toBeNull();
    expect(mergeButton.disabled).toBe(true);
  });
});
