using DSTX.Tweaks.App.Models;

namespace DSTX.Tweaks.App.Services;

public sealed class TaskQueueService
{
    private readonly PowerShellRunner _runner;
    private readonly Action<string> _log;
    private readonly Action<TweakActionItem, string> _setStatus;

    public TaskQueueService(Action<string> log, Action<TweakActionItem, string> setStatus)
    {
        _log = log;
        _setStatus = setStatus;
        _runner = new PowerShellRunner(log);
    }

    public async Task RunActionAsync(TweakActionItem action, TaskItem task, CancellationToken cancellationToken = default)
    {
        task.Status = "RUNNING";
        _setStatus(action, "RUNNING");
        _log("RUNNING: " + action.Name);

        try
        {
            var exitCode = await _runner.RunActionAsync(action.Action, cancellationToken);
            if (exitCode == 0)
            {
                task.Status = "DONE";
                _setStatus(action, "DONE");
                _log("DONE: " + action.Name);
            }
            else
            {
                task.Status = "FAILED";
                _setStatus(action, "FAILED");
                _log($"FAILED: {action.Name} (exit {exitCode})");
            }
        }
        catch (Exception ex)
        {
            task.Status = "FAILED";
            _setStatus(action, "FAILED");
            _log("FAILED: " + action.Name + " -> " + ex.Message);
        }
    }
}
