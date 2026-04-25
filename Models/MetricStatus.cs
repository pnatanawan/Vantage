namespace Vantage.Models;

public enum MetricStatus
{
    Green,
    Yellow,
    Red,
    Gray
}

public class MetricCard
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string DisplayValue { get; set; } = "--";
    public string Target { get; set; } = "";
    public MetricStatus Status { get; set; } = MetricStatus.Gray;
    public string Detail { get; set; } = "";
}
