---
description: "Add a new metric parser to MetricsService for a new ITUP tracking category"
---

Add a new ITUP metric parser to `Services/MetricsService.cs`.

**Metric name**: ${input:metricName}
**Evidence log section header**: ${input:sectionHeader}  
**Table columns**: ${input:tableColumns}
**Target/threshold**: ${input:target}
**Green/Yellow/Red conditions**: ${input:thresholds}

Follow the existing parser pattern:
1. Create `private MetricCard Parse{Name}(string content, DateTime planStart)` 
2. Use `ExtractSection()` to get the markdown section
3. Parse table rows with regex
4. Return MetricCard with computed status
5. Add to the `parsers` array in `GetMetrics()`

Return Gray status when no data is available. Never throw exceptions.
