namespace Vantage.Models;

public class VantageSettings
{
    public string TfsBaseUrl { get; set; } = "";
    public string MyGuid { get; set; } = "";
    public string MyName { get; set; } = "";
    public string EvidenceLogPath { get; set; } = "";
    public string PlaybookPath { get; set; } = "";
    public int CacheTtlMinutes { get; set; } = 5;
    public PlanConfig Plan { get; set; } = new();

    // AI API keys — populated from User Secrets, never appsettings.json
    public string? OpenAiApiKey { get; set; }
    public string? AnthropicApiKey { get; set; }
    public string OpenAiModel { get; set; } = "gpt-4o";
    public string AnthropicModel { get; set; } = "claude-sonnet-4-20250514";
}
