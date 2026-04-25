---
name: ai-integration
description: 'AI API integration with OpenAI and Anthropic for Vantage. Use when adding AI-powered features, setting up API clients, managing prompts, or configuring API keys.'
---

# AI API Integration

## When to Use
- Adding OpenAI or Anthropic API calls
- Creating AI-powered analysis features
- Managing system prompts
- Setting up API key configuration

## Key Management
```bash
# Local dev — .NET User Secrets
dotnet user-secrets init
dotnet user-secrets set "Vantage:OpenAiApiKey" "sk-..."
dotnet user-secrets set "Vantage:AnthropicApiKey" "sk-ant-..."
```

Keys bind to `VantageSettings.OpenAiApiKey` and `VantageSettings.AnthropicApiKey`.

## Service Pattern

### Interface
```csharp
public interface IAiService
{
    Task<string> CompleteAsync(string systemPrompt, string userMessage, CancellationToken ct = default);
    Task<string> CompleteWithContextAsync(string systemPrompt, string userMessage, string context, CancellationToken ct = default);
}
```

### OpenAI Implementation
- Endpoint: `https://api.openai.com/v1/chat/completions`
- Auth: `Authorization: Bearer {key}`
- Model: `gpt-4o` (configurable)
- Register as typed HttpClient in Program.cs

### Anthropic Implementation
- Endpoint: `https://api.anthropic.com/v1/messages`
- Auth: `x-api-key: {key}`, `anthropic-version: 2023-06-01`
- Model: `claude-sonnet-4-20250514` (configurable)
- Register as typed HttpClient in Program.cs

## Prompt Management
- Store system prompts as `.txt` files in `Prompts/` directory
- Load at startup, cache in memory
- Use string interpolation for dynamic context

## Error Handling
- 429 Too Many Requests → retry with backoff
- 500/503 → retry once, then fail gracefully
- Timeout (30s default) → fail with user-friendly message
- Never expose raw API errors to UI

## Security
- Validate all user input before sending to AI
- Do not log API keys or full prompts in production
- Rate limit: max N calls per minute (configurable)
