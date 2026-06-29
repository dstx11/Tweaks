namespace DSTX.Tweaks.App.Models;

public sealed class PageItem : ObservableObject
{
    private bool _isSelected;

    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string Group { get; set; } = "";
    public string Icon { get; set; } = "";
    public string Description { get; set; } = "";
    public int Count { get; set; }

    public bool IsSelected
    {
        get => _isSelected;
        set => SetProperty(ref _isSelected, value);
    }
}
