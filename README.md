# ZavaLoanPortal

Customer-facing loan application portal for Zava Bank — a web UI where customers can apply for loans, view application status, and manage their accounts.

## Tech Stack

- **Framework:** ASP.NET WebForms (.NET Framework 4.8)
- **Runtime:** Mono (Linux container support)
- **Containerization:** Docker

## Features

- Loan application submission
- User authentication (Login/Logout)
- Application status dashboard
- Master page layout with consistent navigation

## Getting Started

### Prerequisites

- .NET Framework 4.8 SDK (or Mono)
- Docker (for containerized deployment)

### Run with Docker

```bash
docker build -t zava-loan-portal .
docker run -p 8080:80 zava-loan-portal
```

### Local Development

Open `ZavaLoanPortal.csproj` in Visual Studio or build with MSBuild/Mono.

## Project Structure

```
├── Default.aspx          # Main dashboard page
├── Login.aspx            # User login page
├── Logout.aspx           # Logout handler
├── Site.Master           # Master page layout
├── ZavaLoanPortal.csproj # Project file
├── web.config            # Configuration
├── packages.config       # NuGet dependencies
└── Dockerfile            # Container definition
```
