namespace Vantage.Models;

public class TeamsChatItem
{
    public string OtherPerson { get; set; } = "";
    public string ChatLabel { get; set; } = "";
    public string ChatSource { get; set; } = "";
    public string HoursCategory { get; set; } = "";
    public string Status { get; set; } = "";
    public double? ResponseMinutes { get; set; }
    public string ResponseType { get; set; } = "";
    public DateTime InboundPHT { get; set; }
    public DateTime? ReplyPHT { get; set; }
}
