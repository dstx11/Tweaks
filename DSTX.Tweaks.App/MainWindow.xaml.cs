using System.Windows;
using DSTX.Tweaks.App.ViewModels;

namespace DSTX.Tweaks.App;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        DataContext = new MainViewModel();
    }
}
