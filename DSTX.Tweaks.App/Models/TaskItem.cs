namespace DSTX.Tweaks.App.Models;

public sealed class TaskItem : ObservableObject
{
    private string _status = "QUEUED";

    public string Name { get; set; } = "";

    public string Status
    {
        get => _status;
        set => SetProperty(ref _status, value);
    }
}
