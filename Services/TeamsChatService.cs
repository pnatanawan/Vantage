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

            var now = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow,
                TimeZoneInfo.FindSystemTimeZoneById("Singapore Standard Time"));

            return items
                .Where(c => c.Status is "Late" or "No Reply")
                .Where(c => !IsAfterHoursGracePeriod(c, now))
                .OrderByDescending(c => c.InboundPHT)
                .ToList();
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to load Teams chat data");
            return [];
        }
    }

    /// <summary>
    /// After-hours messages get until end of next business day (6 PM PHT) to respond.
    /// Returns true if the item is within the grace period and should NOT be shown as late/missing.
    /// </summary>
    private static bool IsAfterHoursGracePeriod(TeamsChatItem item, DateTime now)
    {
        if (!item.HoursCategory.Equals("AfterHours", StringComparison.OrdinalIgnoreCase))
            return false;

        var deadline = GetNextBusinessDayEnd(item.InboundPHT);

        // "Late" but replied before the deadline → actually on-time, hide it
        if (item.Status == "Late" && item.ReplyPHT.HasValue && item.ReplyPHT.Value < deadline)
            return true;

        // "No Reply" but deadline hasn't passed yet → not due yet, hide it
        if (item.Status == "No Reply" && now < deadline)
            return true;

        return false;
    }

    /// <summary>
    /// Returns 6 PM on the next business day (Mon-Fri) after the given timestamp.
    /// </summary>
    private static DateTime GetNextBusinessDayEnd(DateTime inboundPht)
    {
        var nextDay = inboundPht.Date.AddDays(1);
        while (nextDay.DayOfWeek is DayOfWeek.Saturday or DayOfWeek.Sunday)
            nextDay = nextDay.AddDays(1);
        return nextDay.AddHours(18); // 6 PM
    }
}
