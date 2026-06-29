using System.Globalization;
using System.Windows.Data;
using System.Windows.Media;

namespace DSTX.Tweaks.App.Converters;

public sealed class RiskBrushConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        var risk = value?.ToString()?.ToUpperInvariant() ?? "";
        return risk switch
        {
            "SAFE" => new SolidColorBrush(Color.FromRgb(20, 83, 45)),
            "MEDIUM" => new SolidColorBrush(Color.FromRgb(120, 53, 15)),
            "DANGER" => new SolidColorBrush(Color.FromRgb(122, 15, 36)),
            "SECURITY" => new SolidColorBrush(Color.FromRgb(88, 28, 135)),
            _ => new SolidColorBrush(Color.FromRgb(36, 26, 33))
        };
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => Binding.DoNothing;
}
