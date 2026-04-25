---
description: "Add a new service class to the Vantage application with proper DI registration"
---

Create a new service class in `Services/`.

**Service name**: ${input:serviceName}
**Purpose**: ${input:purpose}
**Dependencies**: ${input:dependencies}

Follow existing patterns:
1. Create `Services/{ServiceName}.cs` with file-scoped namespace
2. Constructor injection for dependencies (IOptions<VantageSettings>, ILogger<T>, etc.)
3. Async methods with Async suffix where appropriate
4. Register in `Program.cs` with appropriate lifetime (Singleton/Scoped/Transient)
5. If it needs HttpClient, use typed client via `AddHttpClient<T>()`
