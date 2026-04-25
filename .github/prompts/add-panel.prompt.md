---
description: "Add a new dashboard panel or component to the Vantage UI"
---

Add a new UI component to the Vantage dashboard.

**Component purpose**: ${input:purpose}
**Panel location**: ${input:location} (left metrics panel / right actions panel / new section)
**Data source**: ${input:dataSource}

Follow existing patterns:
1. Add markup to `Components/Pages/Home.razor` or create a new component
2. Add CSS to `wwwroot/app.css` using dark theme variables
3. Use existing service injection patterns
4. Handle loading/empty/error states
5. Follow Razor syntax rules (no records in @code, no < in switch expressions)
