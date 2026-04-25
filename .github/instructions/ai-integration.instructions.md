---
description: "AI API integration patterns for Vantage. Use when working with OpenAI, Anthropic, or other AI provider APIs. Covers key management, client setup, and prompt patterns."
applyTo: "Services/Ai*.cs"
---

# AI API Integration

## Key Management
- NEVER store API keys in appsettings.json or source code
- Use .NET User Secrets for local dev: `dotnet user-secrets set "Vantage:OpenAiApiKey" "sk-..."`
- Use environment variables for production
- Keys are bound via `VantageSettings.OpenAiApiKey` and `VantageSettings.AnthropicApiKey`

## Client Pattern
- Register AI clients as typed HttpClients in Program.cs
- Use separate service classes: `OpenAiService`, `AnthropicService`
- Both implement a common `IAiService` interface for swappability
- Cache expensive API calls when appropriate

## Security
- Validate and sanitize all user input before sending to AI APIs
- Do NOT log API keys or full request/response bodies
- Rate limit API calls — these cost money
- Handle API errors gracefully (429 rate limit, 500 server error, timeout)

## Prompt Patterns
- Keep system prompts in separate files under `Prompts/` directory
- Use string interpolation for dynamic context injection
- Keep prompts focused and specific — one task per call
