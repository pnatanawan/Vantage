# Vantage — ITUP Dashboard

## What This Is
A Blazor Server (.NET 9) personal productivity dashboard for tracking ITUP compliance metrics and pending actions from TFS/Azure DevOps.

## Architecture

### Stack
- **Blazor Web App** with Server interactivity (SignalR), no HTTPS
- **.NET 9**, C# 12
- **TFS REST API** (v5.1) with Windows integrated auth (NTLM)
- **IMemoryCache** for API response caching
- **Custom dark CSS** — no Bootstrap, no CSS frameworks

### Structure
```
Models/              — DTOs and config (MetricCard, PendingAction, PlanConfig, VantageSettings)
Services/            — Business logic
  TfsApiService      — HttpClient wrapper with caching for TFS
  PendingActionsService — PR reviews, my PRs, work items + write operations
  MetricsService     — Parses markdown evidence log (9 ITUP metric parsers)
  IAiService         — Interface for AI provider abstraction
Components/
  Pages/Home.razor   — Main dashboard (metrics grid, tabbed actions, progress bar)
  Layout/            — MainLayout (minimal, no nav sidebar)
wwwroot/app.css      — Complete dark theme
Prompts/             — AI system prompts (future)
scripts/             — PowerShell operational scripts
  dashboard-api.ps1  — Legacy PS HTTP API server (original prototype)
  azd-responsiveness.ps1 — AZD responsiveness analysis & evidence collection
  sprint-close-evidence.ps1 — Sprint delivery metrics collection
data/                — ITUP operational data (evidence log, playbook, reports)
  ITUP_EVIDENCE_LOG.md — Agents append evidence here
  ITUP_90_DAY_PLAYBOOK.md — Full operational playbook
  sprint-reports/    — Per-sprint delivery reports
  responsiveness/    — AZD/Teams responsiveness JSON exports
  cache/             — TFS API response cache (gitignored, regeneratable)
legacy-ui/           — Original HTML dashboard (reference)
  index.html         — Single-page PS dashboard frontend
```

### Configuration
All in `appsettings.json` → `Vantage` section → `VantageSettings` class via IOptions.
API keys for AI services use .NET User Secrets (never in source).

## Coding Conventions
- File-scoped namespaces
- Collection expressions (`[]`) for empty collections
- Async suffix on async methods
- `IOptions<VantageSettings>` for configuration everywhere
- `ILogger<T>` for structured logging
- No nullable warnings suppression — handle nulls explicitly

## Razor-Specific Rules
- NO `record` types inside `@code` blocks (parser bug)
- NO `<` in switch expressions (interpreted as HTML)
- Use if/else chains instead of pattern matching with `<`
- `@(expression)` for dynamic CSS attribute values

## Key Data Flow
1. `MetricsService.GetMetrics()` → reads markdown file → regex-parses 9 metric sections → returns `List<MetricCard>`
2. `PendingActionsService.GetAllAsync()` → 3 parallel TFS API calls → returns `PendingActionsResult` (Reviews, MyPrs, WorkItems)
3. Home.razor calls both on init and refresh, renders left panel (metrics) + right panel (actions)

## Future: AI API Integration
- OpenAI and Anthropic APIs via typed HttpClients
- Keys in User Secrets, bound to VantageSettings
- Common `IAiService` interface for provider swapping
- System prompts stored in `Prompts/` directory
