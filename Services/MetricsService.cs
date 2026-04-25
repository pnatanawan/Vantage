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

    public List<MetricCard> GetMetrics()
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

        var parsers = new (string Name, Func<string, DateTime, MetricCard> Parse)[]
        {
            ("Teams Chat", ParseTeams),
            ("Ceremonies", ParseCeremony),
            ("PR Rework", ParsePrRework),
            ("Story Delivery", ParseStoryDelivery),
            ("Defects", ParseDefects),
            ("QA Handoff", ParseQaHandoff),
            ("AI Usage", ParseAiUsage),
            ("Blockers", ParseBlockers),
            ("AZD Response", ParseAzd),
        };

        var results = new List<MetricCard>();
        foreach (var (name, parse) in parsers)
        {
            try
            {
                results.Add(parse(content, planStart));
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
        var rx = new Regex($@"\|\s*{Regex.Escape(monthName)}\s*\|\s*(\d*)\s*\|\s*(\d*)\s*\|");
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

    private MetricCard ParseAiUsage(string content, DateTime planStart)
    {
        var section = ExtractSection(content, "## AI USAGE EVIDENCE", "## BLOCKER");
        var rx = new Regex(@"\|\s*\d{4}-\d{2}-\d{2}\s*\|[^|]+\|[^|]+\|[^|]+\|[^|]+\|");
        var matches = section is not null
            ? rx.Matches(section).Cast<Match>().Where(m => !m.Value.Contains("_example_") && !m.Value.Contains("Date |")).ToList()
            : [];

        if (matches.Count == 0)
            return MakeGray("ai_usage", "AI Usage", ">=50% by Day 60", "No AI usage entries yet. Log usages as you work.");

        return new MetricCard
        {
            Id = "ai_usage", Name = "AI Usage", Target = ">=50% by Day 60",
            Status = MetricStatus.Gray, DisplayValue = $"{matches.Count}",
            Detail = $"{matches.Count} entries logged. Track against assigned stories."
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
        var section = ExtractSection(content, "## AZD RESPONSIVENESS", "## STORY DELIVERY");
        var rx = new Regex(@"\|\s*(\d{4}-\d{2}-\d{2})\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|[^|]+\|\s*([\d.]+)%");
        var matches = section is not null
            ? rx.Matches(section).Cast<Match>()
                .Where(m => DateTime.Parse(m.Groups[1].Value) >= planStart).ToList()
            : [];

        if (matches.Count == 0)
            return MakeGray("azd_responsiveness", "AZD Response", "<8 biz hrs",
                "Run _itup_azd_responsiveness.ps1 -AppendToLog to populate.");

        var last = matches[^1];
        var pct = double.Parse(last.Groups[4].Value);
        var status = pct >= 90 ? MetricStatus.Green : pct >= 80 ? MetricStatus.Yellow : MetricStatus.Red;

        return new MetricCard
        {
            Id = "azd_responsiveness", Name = "AZD Response", Target = "<8 biz hrs",
            Status = status, DisplayValue = $"{pct}%",
            Detail = $"Week of {last.Groups[1].Value}: {last.Groups[3].Value}/{last.Groups[2].Value} on-time"
        };
    }

    // ── Helpers ──────────────────────────────────────────────

    private static string? ExtractSection(string content, string startPattern, string endMarker)
    {
        var startMatch = Regex.Match(content, startPattern, RegexOptions.Multiline);
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
