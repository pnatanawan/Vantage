---
description: "C# service development for Vantage. Use when creating or modifying service classes, API clients, or business logic in .cs files under Services/."
applyTo: "Services/**/*.cs"
---

# Service Development Guidelines

## DI Registration
- Services are registered in `Program.cs`
- `TfsApiService` uses typed HttpClient via `AddHttpClient<T>()` with `UseDefaultCredentials`
- Use `IOptions<VantageSettings>` for configuration
- Use `IMemoryCache` for caching TFS API responses
- Use `ILogger<T>` for structured logging

## TFS API Patterns
- Base URL: configured in `VantageSettings.TfsBaseUrl`
- All endpoints use `api-version=5.1` query parameter
- Windows integrated auth — no tokens or headers needed
- Cache GET responses with configurable TTL
- Use `JsonElement` for flexible TFS response parsing
- Use `TryGetProp()` extension for safe property access on JSON elements

## Error Handling
- Services catch and log exceptions, return safe defaults
- MetricsService returns error MetricCard on parser failure
- PendingActionsService returns empty lists on fetch failure
- Write operations (vote, reply, comment) throw on failure — let the UI handle

## Conventions
- File-scoped namespaces: `namespace Vantage.Services;`
- Async suffix on async methods: `GetAllAsync()`, `VotePrAsync()`
- Private helper methods at bottom of class
