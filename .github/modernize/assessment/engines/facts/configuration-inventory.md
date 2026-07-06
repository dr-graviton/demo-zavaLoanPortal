# Configuration & Externalized Settings Inventory

ZavaLoanPortal externalizes all runtime settings through a single `web.config` file with no environment-specific overrides, no secrets store, and no feature flag framework; configuration is entirely static and embedded in the deployment artifact.

## Configuration Sources

| Source | Type | Path/Location | Notes |
|--------|------|--------------|-------|
| web.config | XML Application Config | `/web.config` | Primary (and only) configuration file; contains connection strings, app settings, and ASP.NET runtime config |
| Dockerfile | Container Build Config | `/Dockerfile` | Defines base image, build steps, exposed port, and startup command |
| packages.config | NuGet Package Config | `/packages.config` | Empty — no third-party NuGet packages declared |
| ZavaLoanPortal.csproj | MSBuild Project File | `/ZavaLoanPortal.csproj` | Declares assembly references and compile targets |

No Spring Cloud Config, Azure App Configuration, AWS AppConfig, Consul KV, HashiCorp Vault, or any external configuration server is in use.

## Build Profiles

| Profile | Activation | Purpose | Key Dependencies/Plugins |
|---------|-----------|---------|--------------------------|
| Debug | Manual (`Configuration=Debug`) | Development build with debug symbols | OutputPath: `bin\` |
| Release | Manual (`Configuration=Release`) | Production build | OutputPath: `bin\` |
| Docker (Mono) | `docker build` | Cross-platform container build using Mono runtime | `mono:6.12`, `mono-xsp4`, `mcs` compiler |

No Maven/Gradle profiles or .NET publish profiles are defined. The Debug and Release MSBuild configurations share identical output paths (`bin\`) and differ only in standard MSBuild debug/optimize switches.

## Runtime Profiles

| Profile | Activation Method | Config Files | Key Overrides |
|---------|------------------|-------------|--------------|
| Single (no profiles) | N/A — no profile switching | `web.config` only | None — all environments share the same config |

No `appsettings.{Environment}.json`, `web.{Environment}.config`, or `ASPNETCORE_ENVIRONMENT` switching is configured. All environments (development, staging, production) use identical configuration.

## Properties Inventory

### ZavaLoanPortal — Connection Strings

| Property Key | Default Value | Profiles | Source |
|-------------|--------------|---------|--------|
| `ZavaBankDb` | `Server=sqlserver,1433;Database=ZavaBankDB;User Id=sa;******;TrustServerCertificate=true;` | All | `web.config` `<connectionStrings>` |

### ZavaLoanPortal — App Settings

| Property Key | Default Value | Profiles | Source |
|-------------|--------------|---------|--------|
| `AuthGatewayLoginUrl` | `http://localhost/auth/Login.aspx` | All | `web.config` `<appSettings>` |
| `AuthGatewayLogoutUrl` | `http://localhost/auth/Logout.aspx` | All | `web.config` `<appSettings>` |
| `LoanOriginationApiUrl` | `http://zava-loan-origination-api:8080/api/loanapplications` | All | `web.config` `<appSettings>` |

### ZavaLoanPortal — ASP.NET Runtime Settings

| Property Key | Default Value | Profiles | Source |
|-------------|--------------|---------|--------|
| `compilation debug` | `true` | All | `web.config` `<system.web>` |
| `targetFramework` | `4.8` | All | `web.config` `<system.web>` |
| `customErrors mode` | `Off` | All | `web.config` `<system.web>` |
| `authentication mode` | `Forms` | All | `web.config` `<system.web>` |
| `forms loginUrl` | `~/Login.aspx` | All | `web.config` `<authentication>` |
| `forms timeout` | `30` (minutes) | All | `web.config` `<authentication>` |
| `forms name` | `.ZAVAAUTH` | All | `web.config` `<authentication>` |
| `forms protection` | `All` | All | `web.config` `<authentication>` |
| `forms slidingExpiration` | `true` | All | `web.config` `<authentication>` |
| `machineKey validationKey` | `[MASKED — hardcoded]` | All | `web.config` `<machineKey>` |
| `machineKey decryptionKey` | `[MASKED — hardcoded]` | All | `web.config` `<machineKey>` |
| `machineKey validation` | `SHA1` | All | `web.config` `<machineKey>` |
| `machineKey decryption` | `AES` | All | `web.config` `<machineKey>` |

## Startup Parameters & Resource Requirements

| Service | Runtime Options | Memory | CPU | Instance Count |
|---------|----------------|--------|-----|---------------|
| ZavaLoanPortal (container) | `xsp4 --port 8080 --address 0.0.0.0 --nonstop` | Not specified (no Docker resource limits) | Not specified | 1 (no scaling config) |

No JVM heap settings (not applicable — .NET runtime). No `-D` system properties or environment variable injection is configured in the Dockerfile.

## Startup Dependency Chain

ZavaLoanPortal has no programmatic startup dependency chain. The application starts directly via `xsp4`. The external dependencies (SQL Server, ZavaAuthGateway, Loan Origination API) are referenced by hardcoded URLs with no health check, wait-for-TCP mechanism (e.g., `dockerize`), Docker Compose `depends_on`, or Kubernetes readiness probe.

**Implicit dependency order** (no enforcement):
1. SQL Server (`sqlserver:1433`) — must be running for any loan product/history queries to succeed
2. ZavaAuthGateway — must be reachable for login/logout redirects to work
3. Loan Origination API — errors on POST are silently swallowed; application continues if unavailable
4. ZavaLoanPortal — starts unconditionally

## Secrets & Sensitive Configuration

| Secret Reference | Type | Storage |
|-----------------|------|---------|
| `ZavaBankDb` connection string password (`****** | Database credential | Plain text in `web.config` |
| `machineKey validationKey` | ASP.NET Forms Auth signing key | Plain text in `web.config` (hardcoded static value) |
| `machineKey decryptionKey` | ASP.NET Forms Auth encryption key | Plain text in `web.config` (hardcoded static value) |

> ⚠️ **Critical**: Both the SQL Server `sa` password and the ASP.NET `machineKey` values are hardcoded in plain text in `web.config`, which is committed to source control. These must be rotated and externalized before deployment to any non-local environment.

### Secrets Provisioning Workflow

No secrets provisioning workflow exists. All sensitive values are stored as plain text in `web.config` and embedded directly in the container image at build time (`COPY . .` in Dockerfile). There is no integration with HashiCorp Vault, Azure Key Vault, AWS Secrets Manager, Kubernetes Secrets, or any equivalent secret store. Secrets are not injected via environment variables at runtime.

**Recommended remediation**: Externalize all sensitive values (database password, machine keys) into environment variables or a secrets manager, and inject them at container startup rather than baking them into the image.

## Feature Flags

No feature flag framework is in use. No `@ConditionalOnProperty`, `IFeatureManager`, LaunchDarkly, Unleash, or custom toggle mechanism is present. All application behavior is unconditional.

| Flag Name | Default | Controlled By |
|-----------|---------|--------------|
| (none detected) | — | — |

## Framework & Runtime Versions

| Component | Version | Source |
|-----------|---------|--------|
| .NET Framework (target) | 4.8 | `ZavaLoanPortal.csproj` `<TargetFrameworkVersion>v4.8</TargetFrameworkVersion>` |
| ASP.NET WebForms | 4.8 (System.Web) | `ZavaLoanPortal.csproj` assembly reference |
| Mono (container runtime) | 6.12 | `Dockerfile` `FROM mono:6.12` |
| XSP4 (web server) | Bundled with Mono 6.12 | `Dockerfile` `apt-get install mono-xsp4` |
| Mono C# Compiler (`mcs`) | Bundled with Mono 6.12 | `Dockerfile` build step |
| MSBuild ToolsVersion | 4.0 | `ZavaLoanPortal.csproj` `ToolsVersion="4.0"` |
| ADO.NET / System.Data | 4.8 | `ZavaLoanPortal.csproj` assembly reference |
| System.Web.Extensions | 4.8 | `ZavaLoanPortal.csproj` assembly reference |
