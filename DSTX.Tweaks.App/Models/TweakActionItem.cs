namespace DSTX.Tweaks.App.Models;

public sealed class TweakActionItem : ObservableObject
{
    private bool _isSelected;
    private string _status = "READY";

    public string Id { get; set; } = "";
    public string PageId { get; set; } = "";
    public string Name { get; set; } = "";
    public string Short { get; set; } = "";
    public string Description { get; set; } = "";
    public string Risk { get; set; } = "SAFE";
    public bool RequiresRestart { get; set; }
    public string Action { get; set; } = "";
    public string CommandPreview { get; set; } = "";
    public List<string> Tags { get; set; } = new();

    public bool IsSelected
    {
        get => _isSelected;
        set => SetProperty(ref _isSelected, value);
    }

    public string Status
    {
        get => _status;
        set => SetProperty(ref _status, value);
    }

    public string RestartLabel => RequiresRestart ? "Restart: yes" : "Restart: no";
}
