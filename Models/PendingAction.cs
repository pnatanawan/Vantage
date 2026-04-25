namespace Vantage.Models;

public class PendingAction
{
    public string Type { get; set; } = ""; // "pr-review", "my-pr", "work-item"
    public int Id { get; set; }
    public string? RepoId { get; set; }
    public string Title { get; set; } = "";
    public string Author { get; set; } = "";
    public DateTimeOffset CreatedUtc { get; set; }
    public double AgeMinutes => (DateTimeOffset.UtcNow - CreatedUtc).TotalMinutes;
    public string ContextLabel { get; set; } = "";
    public string Url { get; set; } = "";
    public string Preview { get; set; } = "";
    public int? ThreadId { get; set; }
}

public class PendingActionsResult
{
    public List<PendingAction> Reviews { get; set; } = [];
    public List<PendingAction> MyPrs { get; set; } = [];
    public List<PendingAction> WorkItems { get; set; } = [];
}
