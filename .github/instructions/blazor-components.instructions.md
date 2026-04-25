---
description: "Blazor component development for Vantage dashboard. Use when creating or modifying .razor files, adding new dashboard panels, metric cards, or action components."
applyTo: "**/*.razor"
---

# Blazor Component Guidelines

## Pattern
- Use `@rendermode InteractiveServer` on pages that need interactivity
- Inject services via `@inject` directives at top of file
- Keep `@code` blocks at the bottom of the file
- Use `StateHasChanged()` after async data updates

## Razor Syntax Gotchas
- Do NOT use `record` types inside `@code` blocks — Razor parser chokes. Use `class` instead.
- Do NOT use `<` in switch expressions — Razor interprets `<` as HTML tag start. Use if/else chains.
- Collection expressions `[]` work fine in `@code` blocks.
- For computed CSS classes, use `@(expression)` syntax.

## Component Structure
```razor
@page "/route"
@rendermode InteractiveServer
@using Vantage.Models
@inject SomeService Svc

<div class="component-root">
    @* markup *@
</div>

@code {
    // fields, lifecycle, event handlers
}
```

## CSS
- All styles in `wwwroot/app.css` (single file, no scoped CSS)
- Use CSS custom properties from the dark theme (--bg-primary, --text-primary, etc.)
- BEM-like naming: `.metric-card`, `.metric-card.green`, `.action-btn.approve`
