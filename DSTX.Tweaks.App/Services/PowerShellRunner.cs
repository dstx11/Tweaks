using System.Diagnostics;
using System.IO;
using System.Text;

namespace DSTX.Tweaks.App.Services;

public sealed class PowerShellRunner
{
    private readonly Action<string> _log;

    public PowerShellRunner(Action<string> log)
    {
        _log = log;
    }

    public async Task<int> RunActionAsync(string actionId, CancellationToken cancellationToken = default)
    {
        var script = FindScript("run-action.ps1");

        var psi = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = $"-NoProfile -ExecutionPolicy Bypass -File \\\"{script}\\\" -Action \\\"{actionId}\\\"",
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8
        };

        using var process = new Process { StartInfo = psi, EnableRaisingEvents = true };

        process.OutputDataReceived += (_, e) =>
        {
            if (!string.IsNullOrWhiteSpace(e.Data))
                _log(e.Data);
        };
        process.ErrorDataReceived += (_, e) =>
        {
            if (!string.IsNullOrWhiteSpace(e.Data))
                _log("ERROR: " + e.Data);
        };

        process.Start();
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();

        await process.WaitForExitAsync(cancellationToken);
        return process.ExitCode;
    }

    private static string FindScript(string scriptName)
    {
        var baseDir = AppContext.BaseDirectory;
        var candidates = new[]
        {
            Path.Combine(baseDir, "scripts", scriptName),
            Path.Combine(Directory.GetCurrentDirectory(), "scripts", scriptName),
            Path.Combine(Directory.GetCurrentDirectory(), "..", "scripts", scriptName),
            Path.Combine(Directory.GetCurrentDirectory(), "..", "..", "scripts", scriptName),
            Path.Combine(Directory.GetCurrentDirectory(), "..", "..", "..", "scripts", scriptName)
        };

        foreach (var candidate in candidates)
            if (File.Exists(candidate))
                return Path.GetFullPath(candidate);

        throw new FileNotFoundException("Script not found: " + scriptName);
    }
}
