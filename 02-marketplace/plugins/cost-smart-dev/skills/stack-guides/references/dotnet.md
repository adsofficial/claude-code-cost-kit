# ASP.NET Core / C#

## Conventions
- New services target the latest .NET LTS release and the matching ASP.NET Core version; do not downgrade an existing project's target framework.
- Nullable reference types on; treat warnings as errors in new projects.
- Dependency injection through `Program.cs` / extension methods (`AddXyz()`); no service locator.
- Options pattern (`IOptions<T>`) for config; secrets from Azure Key Vault or user-secrets locally, never `appsettings.json`.
- `async`/`await` all the way down; pass `CancellationToken`; never `.Result` or `.Wait()`.
- Controllers or Minimal APIs: follow whichever the project already uses. Return `ProblemDetails` for errors.
- Validate input (FluentValidation or DataAnnotations) at the edge. Map entities to DTOs; never return EF entities from APIs.
- Structured logging with `ILogger<T>` and message templates, not string interpolation.

## Testing
- xUnit (or the project's framework) + FluentAssertions if already used; NSubstitute/Moq for fakes.
- API tests with `WebApplicationFactory<Program>`; database tests with SQLite in-memory or Testcontainers, not a shared dev DB.
- Commands: `dotnet build`, `dotnet test --no-build --filter <Area>`.

## Security
- `[Authorize]` by default (fallback policy); explicitly `[AllowAnonymous]` only where intended. Check resource ownership, not just role (IDOR).
- Parameterized queries only; with EF Core never use `FromSqlRaw` with concatenated input (use `FromSqlInterpolated`/parameters).
- JWT: validate issuer, audience, lifetime and signing key; short-lived access tokens.
- CORS: explicit origins, never `AllowAnyOrigin` with credentials.
- Anti-forgery for cookie-auth forms; HTTPS + HSTS; security headers.
- No secrets, connection strings or PII in logs or exception messages returned to clients.
- `dotnet list package --vulnerable --include-transitive` before release.

## Cost & performance
- Avoid N+1: `Include`/projection with `Select`; `AsNoTracking()` for reads; paginate list endpoints.
- `IHttpClientFactory` for outbound calls; cache hot reads (`IMemoryCache` / distributed cache) with expiry.
