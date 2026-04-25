---
name: metric-parser
description: 'ITUP metric parser development for MetricsService. Use when adding, modifying, or debugging metric parsers that read the evidence log markdown file.'
---

# Metric Parser Development

## When to Use
- Adding a new ITUP metric to the dashboard
- Modifying threshold logic for existing metrics
- Debugging regex patterns for evidence log parsing

## Architecture
`MetricsService.GetMetrics()` orchestrates 9 parsers, each returning a `MetricCard`:
- **Id**: kebab-case identifier
- **Name**: Display name
- **DisplayValue**: The number/percentage shown large
- **Target**: What we're aiming for
- **Status**: Green/Yellow/Red/Gray enum
- **Detail**: One-line description of current state

## Existing Parsers

| Parser | Section Header | Target |
|--------|---------------|--------|
| ParseTeams | (inline regex on date rows) | >=95% < 1hr |
| ParseCeremony | ## CEREMONY ATTENDANCE | 100% |
| ParsePrRework | ### Active Tracking (ITUP Period | Avg <=1.5 |
| ParseStoryDelivery | ### Monthly Rollup | >=2 med/mo |
| ParseDefects | ### Tracking (ITUP Period | 0 from own code |
| ParseQaHandoff | ## QA HANDOFF QUALITY | 0 bounces |
| ParseAiUsage | ## AI USAGE EVIDENCE | >=50% by Day 60 |
| ParseBlockers | ## BLOCKER SURFACING | <24hr surfacing |
| ParseAzd | ## AZD RESPONSIVENESS | <8 biz hrs |

## Helpers
- `ExtractSection(content, startPattern, endMarker)` — regex-based section extraction
- `MakeGray(id, name, target, detail)` — shorthand for no-data MetricCard

## Pattern for New Parser
```csharp
private MetricCard ParseXxx(string content, DateTime planStart)
{
    var section = ExtractSection(content, "## SECTION HEADER", "## ");
    if (section is null)
        return MakeGray("xxx", "Xxx", "target", "Section not found.");

    var rx = new Regex(@"\|\s*(\d{4}-\d{2}-\d{2})\s*\|...");
    var matches = rx.Matches(section).Cast<Match>().ToList();
    
    if (matches.Count == 0)
        return MakeGray("xxx", "Xxx", "target", "No entries yet.");

    // compute value, determine status
    var status = value >= threshold ? MetricStatus.Green : MetricStatus.Red;
    
    return new MetricCard
    {
        Id = "xxx", Name = "Xxx", Target = "target",
        Status = status, DisplayValue = $"{value}",
        Detail = $"description"
    };
}
```

Then register in the `parsers` array in `GetMetrics()`.

## Rules
- Never throw — catch exceptions at the orchestrator level
- Return Gray on missing data, not Red
- Filter to ITUP period (planStart) where date data exists
- Match the exact markdown table format from the evidence log
