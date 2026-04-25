using Microsoft.Extensions.AI;
using Microsoft.Extensions.Options;
using OpenAI;
using Vantage.Models;

namespace Vantage.Services;

public class OpenAiService : IAiService
{
    private readonly VantageSettings _settings;
    private readonly ILogger<OpenAiService> _logger;
    private readonly Lazy<IChatClient> _client;

    public OpenAiService(IOptions<VantageSettings> options, ILogger<OpenAiService> logger)
    {
        _settings = options.Value;
        _logger = logger;
        _client = new Lazy<IChatClient>(() =>
        {
            var client = new OpenAIClient(_settings.OpenAiApiKey!);
            return client.GetResponsesClient().AsIChatClient(_settings.OpenAiModel);
        });
    }

    public bool IsConfigured => !string.IsNullOrWhiteSpace(_settings.OpenAiApiKey);

    public async Task<string> CompleteAsync(string systemPrompt, string userMessage, CancellationToken ct = default)
    {
        if (!IsConfigured)
            throw new InvalidOperationException("OpenAI API key is not configured.");

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
            _logger.LogError(ex, "OpenAI API error");
            throw;
        }
    }
}
