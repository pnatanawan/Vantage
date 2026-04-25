# Vantage — ITUP Dashboard

## Project Overview
Vantage is a Blazor Server (.NET 9) personal productivity dashboard for tracking ITUP (Improvement & Trust-building Uplift Plan) compliance. It replaces a PowerShell + HTML prototype with a proper web application.

## Architecture
- **Framework**: Blazor Web App with Server interactivity, .NET 9
- **Auth**: Windows integrated auth (NTLM) for TFS API calls
- **Caching**: IMemoryCache with configurable TTL
- **Data Sources**: TFS REST API (5.1), local markdown evidence log, local markdown playbook
- **Future**: OpenAI and Anthropic API integration for AI-assisted analysis

## Key Services
- `TfsApiService` — HttpClient wrapper with caching for TFS REST API
- `PendingActionsService` — Fetches pending PR reviews, my PRs with comments, active work items; write operations (vote, reply, comment)
- `MetricsService` — Parses markdown evidence log for 9 ITUP metrics using regex

## Configuration
All settings in `appsettings.json` under `Vantage` section. Bound to `VantageSettings` via IOptions pattern.

## Conventions
- C# 12 with file-scoped namespaces
- Collection expressions (`[]`) for empty lists
- Primary constructors where clean
- No nullable warnings suppression — handle nulls explicitly
- Services registered in Program.cs via standard DI
- CSS in wwwroot/app.css — dark theme with CSS custom properties (no Bootstrap)

## File Structure
```
Models/          — DTOs and config classes
Services/        — Business logic and API clients
Components/      — Razor components (Pages/, Layout/)
wwwroot/         — Static assets (app.css)
```

## Do NOT
- Add Bootstrap or any CSS framework — we use custom dark theme CSS
- Use HTTPS — disabled by design for local dev
- Add authentication middleware — this is a personal tool
- Store secrets in appsettings.json — API keys go in user secrets or env vars
