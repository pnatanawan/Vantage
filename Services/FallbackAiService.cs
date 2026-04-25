using Microsoft.Extensions.Options;
using Vantage.Models;

namespace Vantage.Services;

public class FallbackAiService(
    OpenAiService openAi,
    AnthropicService anthropic,
    IOptions<VantageSettings> options,
    ILogger<FallbackAiService> logger) : IAiService
{
    private readonly string _preferred = options.Value.PreferredAiProvider;

    public bool IsConfigured => openAi.IsConfigured || anthropic.IsConfigured;

    public async Task<string> CompleteAsync(string systemPrompt, string userMessage, CancellationToken ct = default)
    {
        var (primary, secondary) = GetOrderedProviders();

        if (primary.IsConfigured)
        {
            try
            {
                return await primary.CompleteAsync(systemPrompt, userMessage, ct);
            }
            catch (Exception ex) when (ex is not OperationCanceledException && secondary.IsConfigured)
            {
                logger.LogWarning(ex, "Primary AI provider ({Provider}) failed, falling back", _preferred);
            }
        }

        if (secondary.IsConfigured)
            return await secondary.CompleteAsync(systemPrompt, userMessage, ct);

        throw new InvalidOperationException("No AI provider is configured. Set OpenAiApiKey or AnthropicApiKey in User Secrets.");
    }

    private (IAiService Primary, IAiService Secondary) GetOrderedProviders() =>
        _preferred.Equals("Anthropic", StringComparison.OrdinalIgnoreCase)
            ? (anthropic, openAi)
            : (openAi, anthropic);
}
