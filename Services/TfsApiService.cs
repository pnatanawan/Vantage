using System.Net.Http.Headers;
using System.Text.Json;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;
using Vantage.Models;

namespace Vantage.Services;

public class TfsApiService
{
    private readonly HttpClient _http;
    private readonly IMemoryCache _cache;
    private readonly VantageSettings _settings;
    private readonly ILogger<TfsApiService> _logger;
    private const string ApiVersion = "api-version=5.1";
    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true
    };

    public TfsApiService(
        HttpClient http,
        IMemoryCache cache,
        IOptions<VantageSettings> settings,
        ILogger<TfsApiService> logger)
    {
        _http = http;
        _cache = cache;
        _settings = settings.Value;
        _logger = logger;
    }

    // ── GET with caching ─────────────────────────────────────
    public async Task<JsonElement?> GetAsync(string relativeUrl)
    {
        var cacheKey = $"tfs:{relativeUrl}";
        if (_cache.TryGetValue(cacheKey, out JsonElement cached))
            return cached;

        var uri = BuildUri(relativeUrl);
        try
        {
            var response = await _http.GetAsync(uri);
            response.EnsureSuccessStatusCode();
            var json = await response.Content.ReadAsStringAsync();
            var doc = JsonDocument.Parse(json);
            var root = doc.RootElement.Clone();

            _cache.Set(cacheKey, root, TimeSpan.FromMinutes(_settings.CacheTtlMinutes));
            return root;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "TFS GET failed: {Uri}", uri);
            return null;
        }
    }

    // ── POST ─────────────────────────────────────────────────
    public async Task<JsonElement?> PostAsync(string relativeUrl, object body)
    {
        var uri = BuildUri(relativeUrl);
        var content = new StringContent(
            JsonSerializer.Serialize(body),
            System.Text.Encoding.UTF8,
            "application/json");

        var response = await _http.PostAsync(uri, content);
        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadAsStringAsync();
        return JsonDocument.Parse(json).RootElement.Clone();
    }

    // ── PUT ──────────────────────────────────────────────────
    public async Task<JsonElement?> PutAsync(string relativeUrl, object body)
    {
        var uri = BuildUri(relativeUrl);
        var content = new StringContent(
            JsonSerializer.Serialize(body),
            System.Text.Encoding.UTF8,
            "application/json");

        var response = await _http.PutAsync(uri, content);
        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadAsStringAsync();
        return JsonDocument.Parse(json).RootElement.Clone();
    }

    // ── PATCH (for work item updates) ────────────────────────
    public async Task<JsonElement?> PatchAsync(string relativeUrl, object body)
    {
        var uri = BuildUri(relativeUrl);
        var content = new StringContent(
            JsonSerializer.Serialize(body),
            System.Text.Encoding.UTF8,
            "application/json-patch+json");

        var request = new HttpRequestMessage(HttpMethod.Patch, uri) { Content = content };
        var response = await _http.SendAsync(request);
        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadAsStringAsync();
        return JsonDocument.Parse(json).RootElement.Clone();
    }

    public void ClearCache() => _cache.Dispose();

    // ── Helpers ──────────────────────────────────────────────
    private string BuildUri(string relativeUrl)
    {
        var baseUrl = _settings.TfsBaseUrl.TrimEnd('/');
        var sep = relativeUrl.Contains('?') ? "&" : "?";
        return $"{baseUrl}/{relativeUrl}{sep}{ApiVersion}";
    }
}
