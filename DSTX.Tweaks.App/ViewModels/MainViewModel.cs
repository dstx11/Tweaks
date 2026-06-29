using System.Collections.ObjectModel;
using System.IO;
using System.Windows;
using DSTX.Tweaks.App.Models;
using DSTX.Tweaks.App.Services;

namespace DSTX.Tweaks.App.ViewModels;

public sealed class MainViewModel : ObservableObject
{
    private readonly CatalogService _catalog = new();
    private readonly TaskQueueService _taskQueue;
    private PageItem _currentPage = new();
    private TweakActionItem _selectedAction = new();
    private string _searchText = "";
    private bool _overrideGuard;
    private string _liveLog = "";

    public ObservableCollection<PageItem> Pages { get; } = new();
    public ObservableCollection<TweakActionItem> Actions { get; } = new();
    public ObservableCollection<TweakActionItem> VisibleActions { get; } = new();
    public ObservableCollection<TaskItem> TaskQueue { get; } = new();

    public RelayCommand SelectPageCommand { get; }
    public RelayCommand SelectActionCommand { get; }
    public RelayCommand ApplySelectedCommand { get; }
    public RelayCommand ApplyThisCommand { get; }
    public RelayCommand UndoSelectedCommand { get; }
    public RelayCommand UndoThisCommand { get; }
    public RelayCommand EnableEverythingCommand { get; }
    public RelayCommand ExportReportCommand { get; }
    public RelayCommand CopyCommandsCommand { get; }
    public RelayCommand OpenLogsCommand { get; }

    public MainViewModel()
    {
        _taskQueue = new TaskQueueService(AppendLog, UpdateActionStatus);

        SelectPageCommand = new RelayCommand(p => SelectPage((PageItem)p!));
        SelectActionCommand = new RelayCommand(a => SelectedAction = (TweakActionItem)a!);
        ApplySelectedCommand = new RelayCommand(async _ => await ApplyAsync(Actions.Where(a => a.IsSelected)));
        ApplyThisCommand = new RelayCommand(async _ => await ApplyAsync(new[] { SelectedAction }), _ => !string.IsNullOrWhiteSpace(SelectedAction.Id));
        UndoSelectedCommand = new RelayCommand(async _ => await QueueSingleAsync("Undo selected", "restore_basic"));
        UndoThisCommand = new RelayCommand(async _ => await QueueSingleAsync("Undo this", "restore_basic"));
        EnableEverythingCommand = new RelayCommand(async _ => await EnableEverythingAsync());
        ExportReportCommand = new RelayCommand(async _ => await QueueSingleAsync("Export report", "export_report"));
        CopyCommandsCommand = new RelayCommand(_ => Clipboard.SetText(SelectedAction.CommandPreview ?? ""));
        OpenLogsCommand = new RelayCommand(_ => OpenFolder(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "DSTX-Tweaks")));

        Load();
    }

    public PageItem CurrentPage
    {
        get => _currentPage;
        set
        {
            SetProperty(ref _currentPage, value);
            RefreshVisibleActions();
        }
    }

    public TweakActionItem SelectedAction
    {
        get => _selectedAction;
        set => SetProperty(ref _selectedAction, value);
    }

    public string SearchText
    {
        get => _searchText;
        set
        {
            SetProperty(ref _searchText, value);
            RefreshVisibleActions();
        }
    }

    public bool OverrideGuard
    {
        get => _overrideGuard;
        set => SetProperty(ref _overrideGuard, value);
    }

    public string LiveLog
    {
        get => _liveLog;
        set => SetProperty(ref _liveLog, value);
    }

    public string SelectedCountLabel => $"{Actions.Count(a => a.IsSelected)} selected";
    public string QueueCountLabel => $"{TaskQueue.Count} tasks";

    private void Load()
    {
        var pages = _catalog.LoadPages();
        var actions = _catalog.LoadActions();

        foreach (var page in pages)
        {
            page.Count = actions.Count(a => a.PageId == page.Id);
            Pages.Add(page);
        }

        foreach (var action in actions)
            Actions.Add(action);

        if (Pages.Count > 0)
            SelectPage(Pages[0]);

        SelectedAction = Actions.FirstOrDefault() ?? new TweakActionItem();

        AppendLog("DSTX Tweaks v0.8.3 release-pipeline build loaded.");
        AppendLog("UI shell ready. PowerShell backend is script-based.");
    }

    private void SelectPage(PageItem page)
    {
        foreach (var p in Pages)
            p.IsSelected = p == page;

        CurrentPage = page;
    }

    private void RefreshVisibleActions()
    {
        VisibleActions.Clear();

        var query = Actions.Where(a => a.PageId == CurrentPage.Id);

        if (!string.IsNullOrWhiteSpace(SearchText))
        {
            query = Actions.Where(a =>
                a.Name.Contains(SearchText, StringComparison.OrdinalIgnoreCase) ||
                a.Short.Contains(SearchText, StringComparison.OrdinalIgnoreCase) ||
                a.Description.Contains(SearchText, StringComparison.OrdinalIgnoreCase) ||
                a.PageId.Contains(SearchText, StringComparison.OrdinalIgnoreCase));
        }

        foreach (var action in query)
            VisibleActions.Add(action);

        OnPropertyChanged(nameof(SelectedCountLabel));
    }

    private async Task EnableEverythingAsync()
    {
        var result = MessageBox.Show(
            "This will queue every action. Valorant Guard blocks guarded security tweaks unless Override Guard is enabled. Continue?",
            "ENABLE EVERYTHING",
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);

        if (result != MessageBoxResult.Yes)
            return;

        foreach (var action in Actions)
            action.IsSelected = true;

        OnPropertyChanged(nameof(SelectedCountLabel));
        await ApplyAsync(Actions);
    }

    private async Task ApplyAsync(IEnumerable<TweakActionItem> actions)
    {
        var selected = actions.Where(a => !string.IsNullOrWhiteSpace(a.Id)).ToList();
        if (selected.Count == 0)
        {
            AppendLog("No actions selected.");
            return;
        }

        foreach (var action in selected)
        {
            if (!OverrideGuard && action.Tags.Any(t => t.Equals("valorant-risk", StringComparison.OrdinalIgnoreCase)))
            {
                action.Status = "SKIPPED BY GUARD";
                AppendLog($"SKIPPED BY GUARD: {action.Name}");
                continue;
            }

            var task = new TaskItem { Name = action.Name, Status = "QUEUED" };
            TaskQueue.Add(task);
            OnPropertyChanged(nameof(QueueCountLabel));
            await _taskQueue.RunActionAsync(action, task);
        }
    }

    private async Task QueueSingleAsync(string name, string actionId)
    {
        var action = new TweakActionItem
        {
            Id = actionId,
            Action = actionId,
            Name = name,
            CommandPreview = $"scripts\\run-action.ps1 -Action {actionId}",
            Status = "READY"
        };
        var task = new TaskItem { Name = name, Status = "QUEUED" };
        TaskQueue.Add(task);
        OnPropertyChanged(nameof(QueueCountLabel));
        await _taskQueue.RunActionAsync(action, task);
    }

    private void UpdateActionStatus(TweakActionItem action, string status)
    {
        Application.Current.Dispatcher.Invoke(() => action.Status = status);
    }

    private void AppendLog(string line)
    {
        Application.Current.Dispatcher.Invoke(() =>
        {
            LiveLog += $"[{DateTime.Now:HH:mm:ss}] {line}{Environment.NewLine}";
        });
    }

    private static void OpenFolder(string path)
    {
        Directory.CreateDirectory(path);
        System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
        {
            FileName = path,
            UseShellExecute = true
        });
    }
}
