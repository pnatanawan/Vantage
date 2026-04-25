namespace Vantage.Models;

public class PlanConfig
{
    public DateTime Start { get; set; }
    public DateTime End { get; set; }
    public int TotalDays { get; set; }
    public List<Checkpoint> Checkpoints { get; set; } = [];
    
    public double ElapsedDays => Math.Max(0, (DateTime.Now - Start).TotalDays);
    public int CurrentDay => (int)Math.Min(Math.Ceiling(ElapsedDays), TotalDays);
    public double ProgressPercent => Math.Min(ElapsedDays / TotalDays * 100, 100);

    public Checkpoint? NextCheckpoint =>
        Checkpoints.FirstOrDefault(c => c.Date > DateTime.Now);
}

public class Checkpoint
{
    public string Name { get; set; } = "";
    public DateTime Date { get; set; }
    public string Type { get; set; } = "diagnostic"; // "diagnostic" or "formal"
    public int Day { get; set; }
    public double PositionPercent(int totalDays) => (double)Day / totalDays * 100;
    public bool IsPassed => Date <= DateTime.Now;
}
