# Core Business Workflows

ZavaLoanPortal is a customer-facing loan application portal that allows authenticated borrowers to browse available loan products, submit multi-step loan applications, and view their application history.

## Domain Entities

| Entity | Service / Bounded Context | Description | Key Relationships |
|--------|--------------------------|-------------|-------------------|
| LoanProduct | Loan Product Catalog | A type of loan offered by the bank (e.g., personal loan, mortgage) with a unique name and active/inactive status | Referenced by LoanApplication |
| LoanApplication | Loan Application | A customer's request for a specific loan product; records the requested amount, term, purpose, status, and assigned officer | Belongs to a LoanProduct; associated with a Customer (by ID) |
| Customer | Customer Identity (external) | Identified by a numeric ID stored in `LoanApplications.CustomerID`; personal details (name) are captured in the wizard form but not persisted locally | Links LoanApplication to an individual borrower |

## Service-to-Domain Mapping

| Service | Domain Context | Owned Entities | External Dependencies |
|---------|---------------|----------------|----------------------|
| ZavaLoanPortal | Loan Application Management | LoanProduct, LoanApplication | ZavaAuthGateway (authentication), Loan Origination API (downstream processing) |
| ZavaAuthGateway | Identity & Authentication | User identity / session (opaque) | None from portal's perspective |
| Loan Origination API | Loan Processing (external) | Unknown — receives XML payload; portal does not process its response | ZavaLoanPortal (source of loan application data) |

## Primary Workflows

### Workflow 1: User Authentication

Before accessing any loan functionality, the user must be authenticated. `Login.aspx` detects unauthenticated users and redirects the browser to the ZavaAuthGateway login URL (configured via `AuthGatewayLoginUrl`). The gateway sets an ASP.NET Forms Authentication cookie (`.ZAVAAUTH`) and redirects back to the portal. The portal validates the cookie on every request; unauthenticated requests to any page other than `Login.aspx` or `Logout.aspx` are automatically redirected to the login page.

**Steps:**
1. User accesses `Default.aspx` without a valid auth cookie.
2. Portal redirects to `Login.aspx?ReturnUrl=/Default.aspx`.
3. `Login.aspx` redirects browser to `AuthGatewayLoginUrl?ReturnUrl=...`.
4. AuthGateway authenticates the user and sets the `.ZAVAAUTH` cookie.
5. Browser is redirected back to the original return URL.
6. Portal validates the Forms Authentication cookie and grants access.

### Workflow 2: Loan Application Submission

The primary business workflow allows authenticated customers to submit a new loan application through a four-step wizard on `Default.aspx`.

**Steps:**
1. **Page Load** — Portal fetches active loan products and the customer's 25 most recent applications from the database.
2. **Step 1 (Personal Info)** — Customer provides first name and last name.
3. **Step 2 (Contact Info)** — Customer provides contact details.
4. **Step 3 (Loan Details)** — Customer selects a loan product, enters requested amount and term (months). Wizard validates that amount and term are valid numeric values before proceeding; invalid input cancels navigation and displays an error.
5. **Step 4 (Review)** — Portal displays a summary of the entered data (customer name, amount, term) for review.
6. **Finish** — On confirmation, the portal:
   a. Inserts a new `LoanApplications` row into the database with status `Submitted`, the current date, and the logged-in user as `AssignedOfficer`.
   b. Sends an XML payload to the Loan Origination API via HTTP POST.
7. **Confirmation** — Submission status is displayed and the loan history grid is refreshed.

### Workflow 3: Loan History Viewing

On every authenticated page load of `Default.aspx`, the portal retrieves and displays the 25 most recent loan applications from the database in a `GridView`. Each row includes application ID, customer ID, requested amount, term, status, and application date. Users can select a row with the "ReviewApplication" command; this currently only updates a status label (no detailed review view is implemented).

### Workflow 4: Logout

The user navigates to `Logout.aspx`, which calls `FormsAuthentication.SignOut()` to clear the auth cookie, then redirects the browser to the `AuthGatewayLogoutUrl`. No server-side session data is explicitly cleared beyond the Forms Authentication cookie.

## Cross-Service Data Flows

ZavaLoanPortal has two outbound data flows:

1. **Authentication delegation**: The portal does not perform authentication itself. It passes the user to ZavaAuthGateway via browser redirect and trusts the resulting Forms Authentication cookie. No server-to-server call is made; the gateway is opaque to the portal.

2. **Loan origination forwarding**: When a loan application is submitted, the portal constructs a minimal XML document and HTTP POSTs it to the Loan Origination API. The API's response is read but discarded; the portal makes no decision based on the downstream result. If the API is unavailable, the error is silently caught and the application is still recorded in the local database. This means the local database and the Loan Origination API can be out of sync if the downstream POST fails.

## Business Workflow Sequence

```mermaid
sequenceDiagram
    participant Customer as "Customer (Browser)"
    participant Portal as "ZavaLoanPortal"
    participant AuthGW as "ZavaAuthGateway"
    participant DB as "SQL Server (ZavaBankDB)"
    participant LoanAPI as "Loan Origination API"

    Customer->>Portal: Access Default.aspx (no auth cookie)
    Portal-->>Customer: Redirect to Login.aspx
    Customer->>Portal: GET Login.aspx
    Portal-->>Customer: Redirect to AuthGateway login
    Customer->>AuthGW: Authenticate
    AuthGW-->>Customer: Set .ZAVAAUTH cookie, redirect to Default.aspx

    Customer->>Portal: GET Default.aspx (authenticated)
    Portal->>DB: Fetch active loan products
    DB-->>Portal: LoanProducts list
    Portal->>DB: Fetch 25 most recent applications
    DB-->>Portal: LoanApplications list
    Portal-->>Customer: Render loan wizard and history

    Customer->>Portal: Step 1 - Enter personal info (postback)
    Portal-->>Customer: Advance wizard to Step 2
    Customer->>Portal: Step 2 - Enter contact info (postback)
    Portal-->>Customer: Advance wizard to Step 3
    Customer->>Portal: Step 3 - Select product, enter amount and term (postback)
    alt Amount and term are valid numbers
        Portal-->>Customer: Advance wizard to Step 4 (review)
    else Validation fails
        Portal-->>Customer: Show error, stay on Step 3
    end
    Customer->>Portal: Step 4 - Confirm and submit (postback)
    Portal->>DB: INSERT INTO LoanApplications (status=Submitted)
    DB-->>Portal: Row inserted
    Portal->>LoanAPI: POST XML loan application
    alt Loan Origination API available
        LoanAPI-->>Portal: HTTP 200
    else API unavailable or error
        Note over Portal: Error silently swallowed; DB record persists
    end
    Portal->>DB: Refresh loan history (top 25)
    DB-->>Portal: Updated applications
    Portal-->>Customer: Show submission confirmation and updated history
```

## Business Rules & Decision Logic

### Validation Rules

- **Loan amount**: Must be a valid `decimal` value. Checked in `wizLoanApplication_NextButtonClick` when advancing from Step 3 (Loan Details). Invalid value cancels wizard navigation and displays "Enter valid loan amount and term."
- **Loan term**: Must be a valid `int` (months). Checked simultaneously with amount on Step 3 advancement.
- **Authentication gate**: All pages except `Login.aspx` and `Logout.aspx` deny unauthenticated users; handled by ASP.NET Forms Authentication (`<deny users="?" />`).
- **Customer ID**: Parsed from a text field with `int.Parse` — no range or existence check; defaults to `1` on page load.

### State Transitions

| State | Trigger | Notes |
|-------|---------|-------|
| `Submitted` | User completes wizard and clicks Finish | Only status written by the portal; no update/approval workflow implemented |

No state machine or approval workflow is implemented. The `Status` field is set to the literal string `"Submitted"` at insert time and is never subsequently updated by this application.

### Business Constraints

- Loan history is capped at 25 most recent applications per page load (no pagination).
- There is no duplicate application check — customers can submit multiple applications for the same product.
- The `AssignedOfficer` is automatically set to the authenticated user's identity name (`User.Identity.Name`), not selected by the user.

### Cross-Cutting Concerns

- **Transactions**: No explicit transaction management. Each database operation uses its own connection and command. If the `INSERT` succeeds but the downstream API POST fails, there is no rollback — the application is recorded in the database with no corresponding entry in the Loan Origination API.
- **Error handling**: The `SubmitApi` method wraps the HTTP POST in a `try/catch` with an empty `catch {}` block — all API call errors are silently discarded.
- **Audit/logging**: No logging framework is in use. No audit trail is written for application submissions, login events, or errors.
- **Authorization**: Access control is binary (authenticated vs. unauthenticated). There are no role-based checks; any authenticated user can view all 25 most recent loan applications regardless of their customer ID.
