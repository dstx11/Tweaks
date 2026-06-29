using System.IO;
using System.Text.Json;
using DSTX.Tweaks.App.Models;

namespace DSTX.Tweaks.App.Services;

public sealed class CatalogService
{
    private readonly JsonSerializerOptions _options = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true
    };

    public List<PageItem> LoadPages()
    {
        var path = FindFile("catalog", "pages.catalog.json");
        return JsonSerializer.Deserialize<CatalogRoot<PageItem>>(File.ReadAllText(path), _options)?.Items ?? new();
    }

    public List<TweakActionItem> LoadActions()
    {
        var path = FindFile("catalog", "tweaks.catalog.json");
        return JsonSerializer.Deserialize<CatalogRoot<TweakActionItem>>(File.ReadAllText(path), _options)?.Items ?? new();
    }

    public List<AppCatalogItem> LoadApps()
    {
        var path = FindFile("catalog", "apps.catalog.json");
        return JsonSerializer.Deserialize<CatalogRoot<AppCatalogItem>>(File.ReadAllText(path), _options)?.Items ?? new();
    }

    private static string FindFile(params string[] parts)
    {
        var baseDir = AppContext.BaseDirectory;
        var candidates = new[]
        {
            Path.Combine(new[] { baseDir }.Concat(parts).ToArray()),
            Path.Combine(new[] { Directory.GetCurrentDirectory(), ".." }.Concat(parts).ToArray()),
            Path.Combine(new[] { Directory.GetCurrentDirectory(), "..", ".." }.Concat(parts).ToArray()),
            Path.Combine(new[] { Directory.GetCurrentDirectory(), "..", "..", ".." }.Concat(parts).ToArray())
        };

        foreach (var candidate in candidates)
            if (File.Exists(candidate))
                return Path.GetFullPath(candidate);

        throw new FileNotFoundException("Catalog file not found: " + string.Join("/", parts));
    }

    private sealed class CatalogRoot<T>
    {
        public List<T> Items { get; set; } = new();
    }
}
