using Anthropic;
using Microsoft.Extensions.AI;
using Microsoft.Extensions.Options;
using Vantage.Models;

namespace Vantage.Services;

public class AnthropicService : IAiService
{
    private readonly VantageSettings _settings;
    private readonly ILogger<AnthropicService> _logger;
    private readonly Lazy<IChatClient> _client;

    public AnthropicService(IOptions<VantageSettings> options, ILogger<AnthropicService> logger)
    {
        _settings = options.Value;
        _logger = logger;
        _client = new Lazy<IChatClient>(() =>
        {
            var client = new AnthropicClient { ApiKey = _settings.AnthropicApiKey! };
            return client.AsIChatClient(_settings.AnthropicModel);
        });
    }

    public bool IsConfigured => !string.IsNullOrWhiteSpace(_settings.AnthropicApiKey);

    public async Task<string> CompleteAsync(string systemPrompt, string userMessage, CancellationToken ct = default)
    {
        if (!IsConfigured)
            throw new InvalidOperationException("Anthropic API key is not configured.");

        try
        {
            var messages = new List<ChatMessage>
            {
                new(ChatRole.System, systemPrompt),
                new(ChatRole.User, userMessage)
            };

            var response = await _client.Value.GetResponseAsync(messages, cancellationToken: ct);
            return response.Text ?? "";
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            _logger.LogError(ex, "Anthropic API error");
            throw;
        }
    }
}
