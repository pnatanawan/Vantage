using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Options;
using Vantage.Models;

namespace Vantage.Services;

public class MetricsService
{
    private readonly VantageSettings _settings;
    private readonly ILogger<MetricsService> _logger;

    public MetricsService(IOptions<VantageSettings> settings, ILogger<MetricsService> logger)
    {
        _settings = settings.Value;
        _logger = logger;
    }

    public List<MetricCard> GetMetrics(AiUsageResult? aiUsage = null)
    {
        if (!File.Exists(_settings.EvidenceLogPath))
        {
            return [new MetricCard
            {
                Id = "error", Name = "Evidence Log", Status = MetricStatus.Red,
                DisplayValue = "NOT FOUND", Target = "File missing",
                Detail = _settings.EvidenceLogPath
            }];
        }

        var content = File.ReadAllText(_settings.EvidenceLogPath);
        var planStart = _settings.Plan.Start;

        var parsers = new (string Name, string Category, Func<string, DateTime, MetricCard> Parse)[]
        {
            ("Teams Chat", "Responsiveness", ParseTeams),
            ("Ceremonies", "Attendance", ParseCeremony),
            ("PR Rework", "Quality", ParsePrRework),
            ("Story Delivery", "Delivery", ParseStoryDelivery),
            ("Defects", "Quality", ParseDefects),
            ("QA Handoff", "Quality", ParseQaHandoff),
            ("Blockers", "Delivery", ParseBlockers),
            ("AZD Response", "Refinement", ParseAzd),
        };

        var results = new List<MetricCard>();
        foreach (var (name, category, parse) in parsers)
        {
            try
            {
                var card = parse(content, planStart);
                card.Category = category;
                results.Add(card);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Metric parser '{Name}' failed", name);
                results.Add(new MetricCard
                {
                    Id = $"error_{name}", Name = name, Status = MetricStatus.Red,
                    DisplayValue = "ERR", Target = "Parser failed", Detail = ex.Message
                });
            }
        }

        // AI Usage metric from live TFS data (not file-parsed)
        results.Add(BuildAiUsageCard(aiUsage));

        return results;
    }

    // ── Individual Parsers ───────────────────────────────────

    private MetricCard ParseTeams(string content, DateTime planStart)
    {
        var rx = new Regex(@"\|\s*(\d{4}-\d{2}-\d{2})\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*([\d.]+)%\s*\|");
        var all = rx.Matches(content);
        var itup = all.Where(m => DateTime.Parse(m.Groups[1].Value) >= planStart).ToList();

        if (itup.Count == 0)
        {
            var recent = all.Where(m => DateTime.Parse(m.Groups[1].Value) >= new DateTime(2026, 1, 1)).ToList();
            var detail = recent.Count > 0
                ? $"Pre-ITUP: {recent[^1].Groups[5].Value}% (week of {recent[^1].Groups[1].Value})"
                : "No data collected yet.";

            return new MetricCard
            {
                Id = "teams_responsiveness", Name = "Teams Chat", Target = ">=95% < 1hr",
                Status = MetricStatus.Gray, DisplayValue = "--", Detail = detail
            };
        }

        var last = itup[^1];
        var pct = double.Parse(last.Groups[5].Value);
        var status = pct >= 95 ? MetricStatus.Green : pct >= 85 ? MetricStatus.Yellow : MetricStatus.Red;

        return new MetricCard
        {
            Id = "teams_responsiveness", Name = "Teams Chat", Target = ">=95% < 1hr",
            Status = status, DisplayValue = $"{pct}%",
            Detail = $"Week of {last.Groups[1].Value}: {last.Groups[3].Value}/{last.Groups[2].Value} on-time, {last.Groups[4].Value} late"
        };
    }

    private MetricCard ParseCeremony(string content, DateTime planStart)
    {
        var section = ExtractSection(content, "## CEREMONY ATTENDANCE", "## ");
        if (section is null)
            return MakeGray("ceremony", "Ceremonies", "100%", "Section not found.");

        var rx = new Regex(@"\|\s*\d{4}-\d{2}-\d{2}\s*\|[^|]+\|\s*(Present|Absent)\s*\|");
        var matches = rx.Matches(section).Cast<Match>().ToList();
        if (matches.Count == 0)
            return MakeGray("ceremony", "Ceremonies", "100%", "No ITUP-period entries yet.");

        var absent = matches.Count(m => m.Groups[1].Value == "Absent");
        var pct = Math.Round((double)(matches.Count - absent) / matches.Count * 100, 1);
        var status = pct >= 100 ? MetricStatus.Green : pct >= 90 ? MetricStatus.Yellow : MetricStatus.Red;

        return new MetricCard
        {
            Id = "ceremony", Name = "Ceremonies", Target = "100%",
            Status = status, DisplayValue = $"{pct}%",
            Detail = $"{matches.Count - absent}/{matches.Count} attended"
        };
    }

    private MetricCard ParsePrRework(string content, DateTime planStart)
    {
        var section = ExtractSection(content, "### Active Tracking (ITUP Period", "---");
        var rx = new Regex(@"\|\s*(\d+)\s*\|\s*\d{4}-\d{2}-\d{2}\s*\|[^|]+\|\s*(\d+)\s*\|");
        var matches = section is not null ? rx.Matches(section).Cast<Match>().ToList() : [];

        if (matches.Count == 0)
            return new MetricCard
            {
                Id = "pr_rework", Name = "PR Rework", Target = "Avg <=1.5",
                Status = MetricStatus.Gray, DisplayValue = "0.50",
                Detail = "Baseline (9mo). No ITUP-period PRs yet."
            };

        var totalRework = matches.Sum(m => int.Parse(m.Groups[2].Value));
        var avg = Math.Round((double)totalRework / matches.Count, 2);
        var status = avg <= 1.0 ? MetricStatus.Green : avg <= 1.5 ? MetricStatus.Yellow : MetricStatus.Red;

        return new MetricCard
        {
            Id = "pr_rework", Name = "PR Rework", Target = "Avg <=1.5",
            Status = status, DisplayValue = $"{avg}",
            Detail = $"{matches.Count} PRs, {totalRework} total rework cycles"
        };
    }

    private MetricCard ParseStoryDelivery(string content, DateTime planStart)
    {
        var section = ExtractSection(content, "### Monthly Rollup", "---");
        if (section is null)
            return MakeGray("story_delivery", "Story Delivery", ">=2 med/mo", "No monthly rollup data.");

        var monthName = DateTime.Now.ToString("MMM yyyy");
        var rx = new Regex($@"\|\s*{Regex.Escape(monthName)}[^|]*\|\s*(\d+)[^|]*\|\s*(\d+)");
        var match = rx.Match(section);

        if (!match.Success || string.IsNullOrWhiteSpace(match.Groups[1].Value))
        {
            var day = DateTime.Now.Day;
            var detail = day <= 10 ? "Early in month. On track to start."
                : day <= 20 ? "Mid-month. Need stories completing."
                : "Late in month. Need at least 2 medium stories.";

            return new MetricCard
            {
                Id = "story_delivery", Name = "Story Delivery", Target = ">=2 med/mo",
                Status = day <= 15 ? MetricStatus.Gray : MetricStatus.Yellow,
                DisplayValue = "0", Detail = detail
            };
        }

        var completed = int.Parse(match.Groups[1].Value);
        var medium = int.TryParse(match.Groups[2].Value, out var m) ? m : 0;
        var status = medium >= 2 ? MetricStatus.Green : medium >= 1 ? MetricStatus.Yellow : MetricStatus.Red;

        return new MetricCard
        {
            Id = "story_delivery", Name = "Story Delivery", Target = ">=2 med/mo",
            Status = status, DisplayValue = $"{completed}", Detail = $"{medium} medium+ this month"
        };
    }

    private MetricCard ParseDefects(string content, DateTime planStart)
    {
        var section = ExtractSection(content, "### Tracking (ITUP Period", "### Trend");
        var rx = new Regex(@"\|\s*(\d+)\s*\|\s*\d{4}-\d{2}-\d{2}\s*\|");
        var matches = section is not null ? rx.Matches(section).Cast<Match>().ToList() : [];
        var defects = matches.Where(m => int.TryParse(m.Groups[1].Value, out var v) && v > 0).ToList();

        var count = defects.Count;
        var status = count == 0 ? MetricStatus.Green : count <= 1 ? MetricStatus.Yellow : MetricStatus.Red;

        return new MetricCard
        {
            Id = "defects", Name = "Defects", Target = "0 from own code",
            Status = status, DisplayValue = $"{count}",
            Detail = count == 0 ? "Baseline: 0 in 6 months. Maintaining." : $"{count} defects in ITUP period"
        };
    }

    private MetricCard ParseQaHandoff(string content, DateTime planStart)
    {
        var section = ExtractSection(content, "## QA HANDOFF QUALITY", "## PR REVIEW");
        var bounceRx = new Regex(@"\|\s*\d+\s*\|[^|]*\|\s*Yes\s*\|");
        var bounces = section is not null ? bounceRx.Matches(section).Count : 0;

        var itupSection = ExtractSection(content, "### ITUP Period.*QA", "---");
        var entryRx = new Regex(@"\|\s*(\d{7,})\s*\|");
        var entries = itupSection is not null ? entryRx.Matches(itupSection).Count : 0;

        if (entries == 0)
            return new MetricCard
            {
                Id = "qa_handoff", Name = "QA Handoff", Target = "0 bounces",
                Status = MetricStatus.Green, DisplayValue = "12/12",
                Detail = "Baseline: 12/12 clean passes. No ITUP entries yet."
            };

        var status = bounces == 0 ? MetricStatus.Green : bounces == 1 ? MetricStatus.Yellow : MetricStatus.Red;
        return new MetricCard
        {
            Id = "qa_handoff", Name = "QA Handoff", Target = "0 bounces",
            Status = status, DisplayValue = $"{entries - bounces}/{entries}",
            Detail = $"{bounces} bounce(s) in ITUP period"
        };
    }

    private static MetricCard BuildAiUsageCard(AiUsageResult? ai)
    {
        const string target = ">=50% by Day 60";
        if (ai is null || ai.TotalItems == 0)
            return MakeGray("ai_usage", "AI Usage", target, "No work items found since ITUP start.");

        var pct = ai.Percentage;
        var status = pct >= 50 ? MetricStatus.Green
            : pct >= 30 ? MetricStatus.Yellow
            : MetricStatus.Red;

        return new MetricCard
        {
            Id = "ai_usage", Name = "AI Usage", Target = target,
            Category = "AI Usage",
            Status = status,
            DisplayValue = $"{pct:0.#}%",
            Detail = $"{ai.AiAssistedItems}/{ai.TotalItems} items, avg {ai.AvgAiUsage}% usage"
        };
    }

    private MetricCard ParseBlockers(string content, DateTime planStart)
    {
        var section = ExtractSection(content, "## BLOCKER SURFACING", "## REFINEMENT");
        var rx = new Regex(@"\|\s*\d{4}-\d{2}-\d{2}\s*\|[^|]+\|[^|]+\|[^|]+\|\s*(Yes|No)\s*\|");
        var matches = section is not null ? rx.Matches(section).Cast<Match>().ToList() : [];

        if (matches.Count == 0)
            return new MetricCard
            {
                Id = "blockers", Name = "Blockers", Target = "<24hr surfacing",
                Status = MetricStatus.Green, DisplayValue = "OK",
                Detail = "No blockers recorded (no blockers = good)."
            };

        var late = matches.Count(m => m.Groups[1].Value == "No");
        var status = late == 0 ? MetricStatus.Green : late == 1 ? MetricStatus.Yellow : MetricStatus.Red;

        return new MetricCard
        {
            Id = "blockers", Name = "Blockers", Target = "<24hr surfacing",
            Status = status, DisplayValue = $"{matches.Count - late}/{matches.Count}",
            Detail = $"{late} late surfacing(s)"
        };
    }

    private MetricCard ParseAzd(string content, DateTime planStart)
    {
        // Try markdown evidence log first
        var section = ExtractSection(content, "## AZD RESPONSIVENESS", "## STORY DELIVERY");
        var rx = new Regex(@"\|\s*(\d{4}-\d{2}-\d{2})\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|[^|]+\|\s*([\d.]+)%");
        var mdMatches = section is not null
            ? rx.Matches(section).Cast<Match>()
                .Where(m => DateTime.Parse(m.Groups[1].Value) >= planStart).ToList()
            : [];

        if (mdMatches.Count > 0)
        {
            var last = mdMatches[^1];
            var pct = double.Parse(last.Groups[4].Value);
            var status = pct >= 90 ? MetricStatus.Green : pct >= 80 ? MetricStatus.Yellow : MetricStatus.Red;

            return new MetricCard
            {
                Id = "azd_responsiveness", Name = "AZD Response", Target = "<8 biz hrs",
                Status = status, DisplayValue = $"{pct}%",
                Detail = $"Week of {last.Groups[1].Value}: {last.Groups[3].Value}/{last.Groups[2].Value} on-time"
            };
        }

        // Fall back to JSON files in data/responsiveness/
        return ParseAzdFromJson(planStart);
    }

    private MetricCard ParseAzdFromJson(DateTime planStart)
    {
        var dataDir = Path.GetDirectoryName(_settings.EvidenceLogPath)!;
        var respDir = Path.Combine(dataDir, "responsiveness");

        if (!Directory.Exists(respDir))
            return MakeGray("azd_responsiveness", "AZD Response", "<8 biz hrs",
                "No responsiveness data directory found.");

        var files = Directory.GetFiles(respDir, "itup_azd_responsiveness_*.json")
            .OrderBy(f => f).ToList();

        if (files.Count == 0)
            return MakeGray("azd_responsiveness", "AZD Response", "<8 biz hrs",
                "Run azd-responsiveness.ps1 to collect data.");

        var entries = new List<(DateTime weekOf, double pct, int onTime, int total)>();
        foreach (var file in files)
        {
            try
            {
                using var doc = JsonDocument.Parse(File.ReadAllText(file));
                var root = doc.RootElement;
                var weekOf = DateTime.Parse(root.GetProperty("weekOf").GetString()!);
                var summary = root.GetProperty("summary");
                var pct = summary.GetProperty("overallPct").GetDouble();
                var onTime = summary.GetProperty("totalOnTime").GetInt32();
                var responded = summary.GetProperty("totalResponded").GetInt32();
                var pending = summary.GetProperty("totalPending").GetInt32();
                entries.Add((weekOf, pct, onTime, responded + pending));
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to parse AZD JSON: {File}", file);
            }
        }

        if (entries.Count == 0)
            return MakeGray("azd_responsiveness", "AZD Response", "<8 biz hrs",
                "No parseable responsiveness data.");

        var itup = entries.Where(e => e.weekOf >= planStart).ToList();

        if (itup.Count > 0)
        {
            var latest = itup[^1];
            var status = latest.pct >= 90 ? MetricStatus.Green
                : latest.pct >= 80 ? MetricStatus.Yellow
                : MetricStatus.Red;

            return new MetricCard
            {
                Id = "azd_responsiveness", Name = "AZD Response", Target = "<8 biz hrs",
                Status = status, DisplayValue = $"{latest.pct}%",
                Detail = $"Week of {latest.weekOf:yyyy-MM-dd}: {latest.onTime}/{latest.total} on-time"
            };
        }

        // Pre-ITUP baseline (same pattern as ParseTeams)
        var recent = entries[^1];
        return new MetricCard
        {
            Id = "azd_responsiveness", Name = "AZD Response", Target = "<8 biz hrs",
            Status = MetricStatus.Gray, DisplayValue = "--",
            Detail = $"Pre-ITUP: {recent.pct}% (week of {recent.weekOf:yyyy-MM-dd})"
        };
    }

    // ── Helpers ──────────────────────────────────────────────

    private static string? ExtractSection(string content, string startPattern, string endMarker)
    {
        var startMatch = Regex.Match(content, Regex.Escape(startPattern), RegexOptions.Multiline);
        if (!startMatch.Success) return null;

        var startIdx = startMatch.Index + startMatch.Length;
        var rest = content[startIdx..];

        var endMatch = Regex.Match(rest, $"(?m)^{Regex.Escape(endMarker)}");
        return endMatch.Success ? rest[..endMatch.Index] : rest;
    }

    private static MetricCard MakeGray(string id, string name, string target, string detail) => new()
    {
        Id = id, Name = name, Target = target,
        Status = MetricStatus.Gray, DisplayValue = "--", Detail = detail
    };
}
