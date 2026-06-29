using System.Globalization;
using System.Windows.Data;
using System.Windows.Media;

namespace DSTX.Tweaks.App.Converters;

public sealed class BooleanToSelectedBrushConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        var selected = value is bool b && b;
        return selected
            ? new SolidColorBrush(Color.FromRgb(122, 15, 36))
            : new SolidColorBrush(Color.FromRgb(15, 15, 21));
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => Binding.DoNothing;
}
