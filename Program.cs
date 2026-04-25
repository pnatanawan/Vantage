using Vantage.Components;
using Vantage.Models;
using Vantage.Services;

var builder = WebApplication.CreateBuilder(args);

// Configuration — resolve relative data paths against content root
builder.Services.Configure<VantageSettings>(opts =>
{
    builder.Configuration.GetSection("Vantage").Bind(opts);
    var root = builder.Environment.ContentRootPath;
    if (!Path.IsPathRooted(opts.EvidenceLogPath))
        opts.EvidenceLogPath = Path.GetFullPath(Path.Combine(root, opts.EvidenceLogPath));
    if (!Path.IsPathRooted(opts.PlaybookPath))
        opts.PlaybookPath = Path.GetFullPath(Path.Combine(root, opts.PlaybookPath));
});

// Caching
builder.Services.AddMemoryCache();

// HTTP client with Windows integrated auth for TFS
builder.Services.AddHttpClient<TfsApiService>()
    .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler
    {
        UseDefaultCredentials = true
    });

// Application services
builder.Services.AddSingleton<MetricsService>();
builder.Services.AddScoped<PendingActionsService>();

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
}

app.UseAntiforgery();

app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
