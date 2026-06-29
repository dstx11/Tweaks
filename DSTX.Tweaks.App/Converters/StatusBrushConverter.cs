using System.Globalization;
using System.Windows.Data;
using System.Windows.Media;

namespace DSTX.Tweaks.App.Converters;

public sealed class StatusBrushConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        var status = value?.ToString()?.ToUpperInvariant() ?? "";
        return status switch
        {
            "DONE" => new SolidColorBrush(Color.FromRgb(34, 197, 94)),
            "RUNNING" => new SolidColorBrush(Color.FromRgb(245, 158, 11)),
            "FAILED" => new SolidColorBrush(Color.FromRgb(239, 68, 68)),
            "SKIPPED" => new SolidColorBrush(Color.FromRgb(139, 92, 246)),
            "SKIPPED BY GUARD" => new SolidColorBrush(Color.FromRgb(139, 92, 246)),
            _ => new SolidColorBrush(Color.FromRgb(154, 148, 155))
        };
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => Binding.DoNothing;
}
