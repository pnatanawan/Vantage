using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using Vantage.Models;

namespace Vantage.Services;

public class TeamsChatService(ILogger<TeamsChatService> logger)
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        Converters = { new FlexDateTimeConverter(), new FlexNullableDateTimeConverter() }
    };

    /// <summary>Handles "yyyy-MM-dd HH:mm:ss" and ISO 8601 formats.</summary>
    private sealed class FlexDateTimeConverter : JsonConverter<DateTime>
    {
        private const string SpaceFormat = "yyyy-MM-dd HH:mm:ss";

        public override DateTime Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            var s = reader.GetString()!;
            return DateTime.TryParseExact(s, SpaceFormat, CultureInfo.InvariantCulture, DateTimeStyles.None, out var dt)
                ? dt
                : DateTime.Parse(s, CultureInfo.InvariantCulture);
        }

        public override void Write(Utf8JsonWriter writer, DateTime value, JsonSerializerOptions options)
            => writer.WriteStringValue(value.ToString("o"));
    }

    private sealed class FlexNullableDateTimeConverter : JsonConverter<DateTime?>
    {
        private const string SpaceFormat = "yyyy-MM-dd HH:mm:ss";

        public override DateTime? Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            if (reader.TokenType == JsonTokenType.Null) return null;
            var s = reader.GetString();
            if (s is null) return null;
            return DateTime.TryParseExact(s, SpaceFormat, CultureInfo.InvariantCulture, DateTimeStyles.None, out var dt)
                ? dt
                : DateTime.Parse(s, CultureInfo.InvariantCulture);
        }

        public override void Write(Utf8JsonWriter writer, DateTime? value, JsonSerializerOptions options)
        {
            if (value is null) writer.WriteNullValue();
            else writer.WriteStringValue(value.Value.ToString("o"));
        }
    }

    public List<TeamsChatItem> GetRecentChats()
    {
        try
        {
            var dir = Path.Combine(AppContext.BaseDirectory, "data", "responsiveness");
            if (!Directory.Exists(dir))
                return [];

            var latestFile = Directory.GetFiles(dir, "teams_responsiveness_*.json")
                .OrderByDescending(f => f)
                .FirstOrDefault();

            if (latestFile is null)
                return [];

            var json = File.ReadAllText(latestFile);
            var items = JsonSerializer.Deserialize<List<TeamsChatItem>>(json, JsonOptions) ?? [];

            return items
                .Where(c => c.Status is "Late" or "No Reply")
                .OrderByDescending(c => c.InboundPHT)
                .ToList();
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to load Teams chat data");
            return [];
        }
    }
}
