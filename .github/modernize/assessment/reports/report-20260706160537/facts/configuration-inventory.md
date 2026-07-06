# Configuration & Externalized Settings Inventory

ZavaLoanPortal has a single configuration source (`web.config`) and no runtime profiles, secrets manager, feature flags, or externalized configuration — all settings including credentials are hardcoded in the configuration file.

## Configuration Sources

| Source | Type | Path/Location | Notes |
|---|---|---|---|
| web.config | XML application config | `/web.config` | Primary (and only) configuration file; contains connection strings, app settings, and ASP.NET system config |
| Dockerfile | Container build config | `/Dockerfile` | Defines base image, build steps, exposed port (8080) |

No environment-specific config files, `.env` files, Spring Cloud Config, Azure App Configuration, Kubernetes ConfigMaps, or Vault references are present.

## Build Profiles

| Profile | Activation | Purpose | Key Dependencies/Plugins |
|---|---|---|---|
| Debug | Default MSBuild config | Development build; output to `bin\` | None beyond SDK defaults |
| Release | Manual (`/p:Configuration=Release`) | Production build; output to `bin\` | None |
| Docker / Mono | `docker build` | Cross-platform Linux container build via Mono `mcs` compiler | mono:6.12, mono-xsp4 |

No Maven/Gradle profiles or JavaScript build tooling is used.

## Runtime Profiles

No runtime profiles are configured. The application has a single `web.config` with no profile-based overrides (no `appsettings.Development.json`, no Spring profiles, no `NODE_ENV` branching). All environments use the same configuration values.

| Profile | Activation Method | Config Files | Key Overrides |
|---|---|---|---|
| (single profile) | N/A | web.config | N/A |

## Properties Inventory

### ZavaLoanPortal — Connection Strings

| Property Key | Default Value | Source |
|---|---|---|
| ZavaBankDb | Server=sqlserver,1433;Database=ZavaBankDB;User Id=sa;******;TrustServerCertificate=true | web.config `<connectionStrings>` |

### ZavaLoanPortal — Application Settings

| Property Key | Default Value | Source |
|---|---|---|
| AuthGatewayLoginUrl | http://localhost/auth/Login.aspx | web.config `<appSettings>` |
| AuthGatewayLogoutUrl | http://localhost/auth/Logout.aspx | web.config `<appSettings>` |
| LoanOriginationApiUrl | http://zava-loan-origination-api:8080/api/loanapplications | web.config `<appSettings>` |

### ZavaLoanPortal — ASP.NET System Configuration

| Property Key | Value | Source |
|---|---|---|
| compilation debug | true | web.config `<system.web>` |
| targetFramework | 4.8 | web.config `<system.web>` |
| httpRuntime targetFramework | 4.8 | web.config `<system.web>` |
| customErrors mode | Off | web.config `<system.web>` |
| authentication mode | Forms | web.config `<system.web>` |
| forms loginUrl | ~/Login.aspx | web.config `<system.web>` |
| forms timeout | 30 (minutes) | web.config `<system.web>` |
| forms name | .ZAVAAUTH | web.config `<system.web>` |
| forms protection | All | web.config `<system.web>` |
| machineKey validation | SHA1 | web.config `<system.web>` |
| machineKey decryption | AES | web.config `<system.web>` |

## Startup Parameters & Resource Requirements

| Service | Runtime Options | Memory | Instance Count |
|---|---|---|---|
| ZavaLoanPortal (IIS) | .NET CLR 4.0, integrated pipeline | Not specified | Not specified |
| ZavaLoanPortal (Docker/Mono) | `xsp4 --port 8080 --address 0.0.0.0 --nonstop` | Not specified | 1 (no scaling config) |

No JVM heap settings, `-D` system properties, or Kubernetes resource limits are configured.

## Startup Dependency Chain

The application has no automated startup dependency chain. At runtime it requires:

1. **SQL Server** must be running and reachable at `sqlserver:1433` with database `ZavaBankDB` — no wait mechanism or readiness check is implemented.
2. **ZavaAuthGateway** must be reachable at the configured URL — no health check or retry logic is present.
3. **Loan Origination API** must be reachable at `zava-loan-origination-api:8080` — failures are silently swallowed.

No `dockerize`, `depends_on`, Kubernetes readiness probes, or Spring Cloud Config retry is configured.

## Secrets & Sensitive Configuration

| Secret Reference | Type | Storage |
|---|---|---|
| ZavaBankDb connection string password | SQL Server SA password | Plaintext in web.config — [MASKED in this document] |
| machineKey validationKey | Forms Auth HMAC key | Hardcoded plaintext in web.config |
| machineKey decryptionKey | Forms Auth encryption key | Hardcoded plaintext in web.config |

> **Critical**: All three secrets are hardcoded in plaintext in `web.config`. There is no secrets manager, environment variable injection, DPAPI encryption, or Key Vault integration.

### Secrets Provisioning Workflow

There is no automated secrets provisioning workflow. Secrets are statically embedded in `web.config` at development time and committed to source control. The database uses the `sa` (system administrator) account, granting unrestricted access to the entire SQL Server instance. The Forms Authentication `machineKey` is static and shared across all deployments, meaning any instance can forge authentication tickets.

Recommended remediation: inject secrets via environment variables or a secrets manager (Azure Key Vault, AWS Secrets Manager, HashiCorp Vault) and remove all credential values from `web.config`.

## Feature Flags

No feature flags are configured. There are no `@ConditionalOnProperty`, `.NET FeatureManagement`, LaunchDarkly, or custom toggle mechanisms in the project.

| Flag Name | Default | Controlled By |
|---|---|---|
| (none detected) | N/A | N/A |

## Framework & Runtime Versions

| Component | Version | Source |
|---|---|---|
| .NET Framework | 4.8 | ZavaLoanPortal.csproj `<TargetFrameworkVersion>` |
| ASP.NET Web Forms | 4.8 | System.Web reference in .csproj |
| Mono (Docker) | 6.12 | Dockerfile `FROM mono:6.12` |
| XSP4 (Mono web server) | Included with mono-xsp4 | Dockerfile apt-get install |
| MSBuild | 4.0 (ToolsVersion) | ZavaLoanPortal.csproj |
| C# | ~7.3 (default for .NET 4.8) | Compiler default |
| SQL Server client | System.Data.SqlClient (.NET 4.8 built-in) | .csproj reference |
