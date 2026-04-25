namespace Vantage.Services;

public interface IAiService
{
    bool IsConfigured { get; }
    Task<string> CompleteAsync(string systemPrompt, string userMessage, CancellationToken ct = default);
}
