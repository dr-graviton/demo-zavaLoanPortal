# Architecture Diagram

ZavaLoanPortal is a .NET Framework 4.8 ASP.NET Web Forms application that provides a loan application portal, delegating authentication to an external auth gateway and persisting data in a SQL Server database.

## Application Architecture

```mermaid
flowchart TD
    subgraph Client["Client Layer"]
        Browser["Web Browser"]
    end
    subgraph App["Application Layer - ASP.NET Web Forms 4.8"]
        Master["Site.Master (Layout)"]
        LoginPage["Login.aspx (Auth Redirect)"]
        DefaultPage["Default.aspx (Loan Portal)"]
        LogoutPage["Logout.aspx (Sign-Out)"]
        FormsAuth["Forms Authentication"]
    end
    subgraph Data["Data Layer"]
        ADO["ADO.NET SqlClient"]
        DB[("SQL Server - ZavaBankDB")]
    end
    subgraph External["External Services"]
        AuthGW["ZavaAuthGateway"]
        LoanAPI["Loan Origination API"]
    end

    Browser -->|"HTTP requests"| Master
    Master -->|"renders"| LoginPage
    Master -->|"renders"| DefaultPage
    Master -->|"renders"| LogoutPage
    LoginPage -->|"redirects to"| AuthGW
    LogoutPage -->|"redirects to"| AuthGW
    DefaultPage -->|"authenticates via"| FormsAuth
    DefaultPage -->|"SQL queries"| ADO
    ADO -->|"CRUD"| DB
    DefaultPage -->|"POST XML payload"| LoanAPI
```

### Technology Stack Summary

| Layer | Technology | Version | Purpose |
|---|---|---|---|
| Presentation | ASP.NET Web Forms | 4.8 | Server-side page rendering |
| Presentation | Site.Master | — | Shared layout and navigation |
| Authentication | Forms Authentication | .NET 4.8 | Cookie-based auth with external gateway delegation |
| Data Access | ADO.NET SqlClient | .NET 4.8 | Direct SQL access to SQL Server |
| Data Storage | SQL Server | — | Persists loan applications and products |
| External | ZavaAuthGateway | — | External identity/authentication service |
| External | Loan Origination API | — | Downstream loan processing service (XML/HTTP) |

### Data Storage & External Services

The application uses a single SQL Server database named `ZavaBankDB` accessed via `System.Data.SqlClient` with direct parameterized queries (no ORM). Two external HTTP services are integrated: `ZavaAuthGateway` handles user authentication and sign-out through redirects, and `Loan Origination API` receives new loan application payloads as XML via HTTP POST.

### Key Architectural Decisions

- **Web Forms page lifecycle**: Each `.aspx` page inherits from `System.Web.UI.Page`, handling requests through server-side event handlers (Page_Load, button clicks, wizard events).
- **Inline SQL data access**: All database interactions use raw ADO.NET `SqlConnection`/`SqlCommand` calls directly in code-behind, with no repository or ORM abstraction layer.
- **External authentication delegation**: Login and logout flows redirect users to a separately deployed `ZavaAuthGateway`, with Forms Authentication cookies managing session state within the portal.

## Component Relationships

```mermaid
flowchart LR
    subgraph Presentation["Presentation"]
        SiteMaster["SiteMaster (MasterPage)"]
        LoginPage["Login (Page)"]
        DefaultPage["Default (Page)"]
        LogoutPage["Logout (Page)"]
    end
    subgraph DataAccess["Data Access"]
        SqlClient["ADO.NET SqlClient"]
    end
    subgraph Infra["Infrastructure"]
        FormsAuth["FormsAuthentication"]
        ConfigMgr["ConfigurationManager"]
        HttpWeb["HttpWebRequest"]
    end

    SiteMaster -->|"hosts"| DefaultPage
    SiteMaster -->|"hosts"| LoginPage
    SiteMaster -->|"hosts"| LogoutPage
    DefaultPage -->|"checks"| FormsAuth
    DefaultPage -->|"reads config"| ConfigMgr
    DefaultPage -->|"queries"| SqlClient
    DefaultPage -->|"calls API"| HttpWeb
    LoginPage -->|"reads config"| ConfigMgr
    LogoutPage -->|"signs out"| FormsAuth
    LogoutPage -->|"reads config"| ConfigMgr
```

### Component Inventory

| Component | Layer | Type | Responsibility |
|---|---|---|---|
| SiteMaster | Presentation | MasterPage | Shared layout, navigation bar, user status display |
| Login | Presentation | Web Forms Page | Redirects unauthenticated users to ZavaAuthGateway |
| Default | Presentation | Web Forms Page | Loan product listing, application wizard, history grid |
| Logout | Presentation | Web Forms Page | Signs out the user and redirects to auth gateway logout |
| FormsAuthentication | Infrastructure | .NET Framework class | Issues and validates Forms Auth cookies |
| ConfigurationManager | Infrastructure | .NET Framework class | Reads connection strings and app settings from web.config |
| ADO.NET SqlClient | Data Access | Database driver | Executes parameterized SQL queries against ZavaBankDB |
| HttpWebRequest | Infrastructure | .NET Framework class | POSTs XML loan application payloads to Loan Origination API |
