namespace DSTX.Tweaks.App.Models;

public sealed class AppCatalogItem
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string Winget { get; set; } = "";
    public string[] Processes { get; set; } = [];
    public string[] Startup { get; set; } = [];
    public string[] Cache { get; set; } = [];
}
