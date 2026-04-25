using System.Text.Json;
using Microsoft.Extensions.Options;
using Vantage.Models;

namespace Vantage.Services;

public class PendingActionsService
{
    private readonly TfsApiService _tfs;
    private readonly VantageSettings _settings;
    private readonly ILogger<PendingActionsService> _logger;

    public PendingActionsService(
        TfsApiService tfs,
        IOptions<VantageSettings> settings,
        ILogger<PendingActionsService> logger)
    {
        _tfs = tfs;
        _settings = settings.Value;
        _logger = logger;
    }

    public async Task<PendingActionsResult> GetAllAsync()
    {
        var reviewsTask = GetPendingReviewsAsync();
        var myPrsTask = GetMyPrsPendingCommentsAsync();
        var workItemsTask = GetActiveWorkItemsAsync();

        await Task.WhenAll(reviewsTask, myPrsTask, workItemsTask);

        return new PendingActionsResult
        {
            Reviews = await reviewsTask,
            MyPrs = await myPrsTask,
            WorkItems = await workItemsTask
        };
    }

    // ── PR Reviews assigned to me ────────────────────────────
    private async Task<List<PendingAction>> GetPendingReviewsAsync()
    {
        try
        {
            var data = await _tfs.GetAsync(
                $"_apis/git/pullrequests?searchCriteria.reviewerId={_settings.MyGuid}&searchCriteria.status=active&$top=50");

            if (data is null) return [];

            var results = new List<PendingAction>();
            foreach (var pr in GetArray(data.Value, "value"))
            {
                var creatorId = pr.TryGetProp("createdBy")?.TryGetProp("id")?.GetString();
                if (creatorId == _settings.MyGuid) continue;

                var myReview = GetArray(pr, "reviewers")
                    .FirstOrDefault(r => r.TryGetProp("id")?.GetString() == _settings.MyGuid);
                if (myReview.ValueKind != JsonValueKind.Undefined)
                {
                    var vote = myReview.TryGetProp("vote")?.GetInt32() ?? 0;
                    if (vote != 0) continue;
                }

                var prId = pr.GetProperty("pullRequestId").GetInt32();
                var created = DateTimeOffset.Parse(pr.GetProperty("creationDate").GetString()!);

                results.Add(new PendingAction
                {
                    Type = "pr-review",
                    Id = prId,
                    RepoId = pr.TryGetProp("repository")?.TryGetProp("id")?.GetString(),
                    Title = $"PR {prId} - {pr.TryGetProp("title")?.GetString()}",
                    Author = pr.TryGetProp("createdBy")?.TryGetProp("displayName")?.GetString() ?? "",
                    CreatedUtc = created,
                    ContextLabel = "PR Review",
                    Url = BuildPrUrl(pr),
                    Preview = pr.TryGetProp("description")?.GetString() ?? ""
                });
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to fetch pending reviews");
            return [];
        }
    }

    // ── My PRs with unreplied comments ───────────────────────
    private async Task<List<PendingAction>> GetMyPrsPendingCommentsAsync()
    {
        try
        {
            var data = await _tfs.GetAsync(
                $"_apis/git/pullrequests?searchCriteria.creatorId={_settings.MyGuid}&searchCriteria.status=active&$top=20");

            if (data is null) return [];

            var results = new List<PendingAction>();
            foreach (var pr in GetArray(data.Value, "value"))
            {
                var prId = pr.GetProperty("pullRequestId").GetInt32();
                var repoId = pr.TryGetProp("repository")?.TryGetProp("id")?.GetString() ?? "";

                var threads = await _tfs.GetAsync(
                    $"_apis/git/repositories/{repoId}/pullRequests/{prId}/threads");
                if (threads is null) continue;

                foreach (var thread in GetArray(threads.Value, "value"))
                {
                    var status = thread.TryGetProp("status")?.GetString();
                    if (status is "closed" or "fixed") continue;

                    var comments = GetArray(thread, "comments")
                        .Where(c => c.TryGetProp("commentType")?.GetString() != "system")
                        .ToList();
                    if (comments.Count == 0) continue;

                    var last = comments[^1];
                    if (last.TryGetProp("author")?.TryGetProp("id")?.GetString() == _settings.MyGuid)
                        continue;

                    var pubDate = last.TryGetProp("publishedDate")?.GetString();
                    if (pubDate is null) continue;
                    var commentDate = DateTimeOffset.Parse(pubDate);

                    results.Add(new PendingAction
                    {
                        Type = "my-pr",
                        Id = prId,
                        RepoId = repoId,
                        Title = $"PR {prId} - {pr.TryGetProp("title")?.GetString()}",
                        Author = last.TryGetProp("author")?.TryGetProp("displayName")?.GetString() ?? "",
                        CreatedUtc = commentDate,
                        ContextLabel = "Comment on my PR",
                        Url = BuildPrUrl(pr),
                        Preview = StripHtml(last.TryGetProp("content")?.GetString() ?? ""),
                        ThreadId = thread.TryGetProp("id")?.GetInt32()
                    });
                }
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to fetch my PRs pending comments");
            return [];
        }
    }

    // ── Active work items assigned to me (with unreplied comment detection) ──
    private async Task<List<PendingAction>> GetActiveWorkItemsAsync()
    {
        try
        {
            var wiql = new
            {
                query = $"""
                    SELECT [System.Id], [System.Title], [System.State], [System.ChangedDate]
                    FROM WorkItems
                    WHERE [System.AssignedTo] = '{_settings.MyName}'
                      AND [System.State] IN ('Active', 'Ready to Work')
                      AND [System.TeamProject] = 'PropertyManagement'
                      AND [System.WorkItemType] IN ('User Story', 'Bug', 'Task')
                    ORDER BY [System.ChangedDate] DESC
                    """
            };

            var result = await _tfs.PostAsync("_apis/wit/wiql", wiql);
            if (result is null) return [];

            var ids = GetArray(result.Value, "workItems")
                .Take(25)
                .Select(w => w.GetProperty("id").GetInt32())
                .ToList();

            if (ids.Count == 0) return [];

            var idList = string.Join(",", ids);
            var fields = "System.Id,System.Title,System.State,System.WorkItemType,System.ChangedDate";
            var details = await _tfs.GetAsync($"_apis/wit/workitems?ids={idList}&fields={fields}");

            if (details is null) return [];

            // Fetch latest comment for each work item in parallel
            var commentTasks = ids.ToDictionary(id => id, id => GetLatestWorkItemCommentAsync(id));
            await Task.WhenAll(commentTasks.Values);

            var results = new List<PendingAction>();
            foreach (var wi in GetArray(details.Value, "value"))
            {
                var f = wi.GetProperty("fields");
                var wiId = wi.GetProperty("id").GetInt32();
                var state = f.TryGetProp("System.State")?.GetString() ?? "";
                var wiType = f.TryGetProp("System.WorkItemType")?.GetString() ?? "";
                var title = f.TryGetProp("System.Title")?.GetString() ?? "";
                var changed = DateTimeOffset.Parse(f.GetProperty("System.ChangedDate").GetString()!);

                var comment = commentTasks[wiId].Result;
                var needsReply = comment is not null &&
                    !string.Equals(comment.Value.AuthorId, _settings.MyGuid, StringComparison.OrdinalIgnoreCase);

                // Only show work items where someone else left the last comment (needs reply)
                if (!needsReply) continue;

                results.Add(new PendingAction
                {
                    Type = "work-item",
                    Id = wiId,
                    Title = $"{wiType} {wiId} - {title}",
                    Author = comment!.Value.AuthorName,
                    CreatedUtc = comment.Value.Date,
                    ContextLabel = $"Reply to {comment.Value.AuthorName}",
                    Preview = comment.Value.Text,
                    Url = $"{_settings.TfsBaseUrl}/_workitems/edit/{wiId}"
                });
            }

            return results.OrderByDescending(a => a.CreatedUtc).ToList();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to fetch active work items");
            return [];
        }
    }

    private readonly record struct WiComment(string AuthorId, string AuthorName, string Text, DateTimeOffset Date);

    private async Task<WiComment?> GetLatestWorkItemCommentAsync(int workItemId)
    {
        try
        {
            var data = await _tfs.GetAsync($"_apis/wit/workItems/{workItemId}/comments");
            if (data is null) return null;

            var comments = GetArray(data.Value, "comments").ToList();
            if (comments.Count == 0) return null;
            var latest = comments[^1];

            var authorId = latest.TryGetProp("createdBy")?.TryGetProp("id")?.GetString() ?? "";
            var authorName = latest.TryGetProp("createdBy")?.TryGetProp("displayName")?.GetString() ?? "";
            var text = StripHtml(latest.TryGetProp("text")?.GetString() ?? "");
            var dateStr = latest.TryGetProp("createdDate")?.GetString();
            var date = dateStr is not null ? DateTimeOffset.Parse(dateStr) : DateTimeOffset.MinValue;

            return new WiComment(authorId, authorName, text, date);
        }
        catch (Exception ex)
        {
            _logger.LogDebug(ex, "Failed to fetch comments for WI {Id}", workItemId);
            return null;
        }
    }

    // ── Write operations ─────────────────────────────────────

    public async Task<AiUsageResult> GetAiUsageAsync(DateTime sinceDate)
    {
        try
        {
            var since = sinceDate.ToString("yyyy-MM-dd");

            // Total work items assigned since ITUP start
            var totalWiql = new
            {
                query = $"""
                    SELECT [System.Id]
                    FROM WorkItems
                    WHERE [System.AssignedTo] = '{_settings.MyName}'
                      AND [System.WorkItemType] IN ('User Story', 'Bug', 'Task')
                      AND [System.State] IN ('Active', 'Ready to Work', 'Resolved', 'Closed')
                      AND [System.ChangedDate] >= '{since}'
                    ORDER BY [System.ChangedDate] DESC
                    """
            };

            var totalResult = await _tfs.PostAsync("_apis/wit/wiql", totalWiql);
            var totalIds = totalResult is not null
                ? GetArray(totalResult.Value, "workItems").Select(w => w.GetProperty("id").GetInt32()).ToList()
                : [];

            if (totalIds.Count == 0)
                return new AiUsageResult();

            // Fetch AI usage field for all items
            var idList = string.Join(",", totalIds.Take(200));
            var details = await _tfs.GetAsync(
                $"_apis/wit/workitems?ids={idList}&fields=System.Id,Custom.AIAssistantUsage");

            if (details is null)
                return new AiUsageResult { TotalItems = totalIds.Count };

            var aiValues = new List<double>();
            foreach (var wi in GetArray(details.Value, "value"))
            {
                var f = wi.GetProperty("fields");
                var aiUsage = f.TryGetProp("Custom.AIAssistantUsage");
                if (aiUsage is not null && aiUsage.Value.ValueKind == JsonValueKind.Number)
                {
                    var val = aiUsage.Value.GetDouble();
                    if (val > 0) aiValues.Add(val);
                }
            }

            return new AiUsageResult
            {
                TotalItems = totalIds.Count,
                AiAssistedItems = aiValues.Count,
                AvgAiUsage = aiValues.Count > 0 ? Math.Round(aiValues.Average(), 1) : 0
            };
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to fetch AI usage metrics");
            return new AiUsageResult();
        }
    }

    public async Task VotePrAsync(int prId, string repoId, int vote)
    {
        await _tfs.PutAsync(
            $"_apis/git/repositories/{repoId}/pullRequests/{prId}/reviewers/{_settings.MyGuid}",
            new { vote });
    }

    public async Task ReplyToPrThreadAsync(int prId, string repoId, int threadId, string content)
    {
        await _tfs.PostAsync(
            $"_apis/git/repositories/{repoId}/pullRequests/{prId}/threads/{threadId}/comments",
            new { content, parentCommentId = 0 });
    }

    public async Task CommentOnWorkItemAsync(int wiId, string content)
    {
        await _tfs.PostAsync(
            $"_apis/wit/workItems/{wiId}/comments",
            new { text = content });
    }

    // ── Helpers ──────────────────────────────────────────────
    private string BuildPrUrl(JsonElement pr)
    {
        var repoName = pr.TryGetProp("repository")?.TryGetProp("name")?.GetString() ?? "OneSite";
        var prId = pr.GetProperty("pullRequestId").GetInt32();
        return $"{_settings.TfsBaseUrl}/_git/{repoName}/pullrequest/{prId}";
    }

    private static IEnumerable<JsonElement> GetArray(JsonElement el, string prop)
    {
        if (el.TryGetProperty(prop, out var arr) && arr.ValueKind == JsonValueKind.Array)
            return arr.EnumerateArray();
        return [];
    }

    private static string StripHtml(string html)
        => System.Text.RegularExpressions.Regex.Replace(html, "<[^>]+>", "");
}

// Extension for safe property access on JsonElement
public static class JsonElementExtensions
{
    public static JsonElement? TryGetProp(this JsonElement el, string name)
        => el.TryGetProperty(name, out var val) ? val : null;
}
