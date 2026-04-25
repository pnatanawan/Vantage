---
name: tfs-api
description: 'TFS REST API integration patterns for Vantage. Use when adding new TFS API calls, modifying data fetchers, or troubleshooting API responses.'
---

# TFS API Integration

## When to Use
- Adding new TFS API endpoints (pull requests, work items, builds, etc.)
- Modifying existing data fetchers in PendingActionsService
- Debugging TFS API response parsing

## API Reference
- Base URL: `https://tfs.realpage.com/tfs/Realpage/PropertyManagement`
- API version: `5.1` (appended automatically by TfsApiService.BuildUri)
- Auth: Windows integrated (NTLM) — no tokens needed

## Common Endpoints
```
GET _apis/git/pullrequests?searchCriteria.reviewerId={guid}&searchCriteria.status=active
GET _apis/git/repositories/{repoId}/pullrequests/{prId}/threads
GET _apis/wit/wiql — POST with WIQL query body
GET _apis/wit/workitems?ids={ids}&$expand=relations
PATCH _apis/git/repositories/{repoId}/pullrequests/{prId}/reviewers/{reviewerGuid} — vote
POST _apis/git/repositories/{repoId}/pullrequests/{prId}/threads/{threadId}/comments — reply
PATCH _apis/wit/workitems/{id} — update work item (JSON Patch)
```

## Patterns
- Use `TfsApiService.GetAsync(relativeUrl)` — handles caching and base URL
- Response is `JsonElement?` — use `TryGetProp()` extension for safe property access
- Array results: check for `value` property, iterate with `EnumerateArray()`
- Date parsing: TFS returns ISO 8601 strings, parse with `DateTimeOffset.Parse()`

## Adding a New Fetcher
1. Add method to PendingActionsService (or new service)
2. Use `_tfs.GetAsync("_apis/...")` for the API call
3. Parse JsonElement response into model objects
4. Handle null/empty responses gracefully
5. If it's a frequently-called endpoint, caching is automatic via TfsApiService
