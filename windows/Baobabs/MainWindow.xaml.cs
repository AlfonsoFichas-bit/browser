using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using System;

// To learn more about WinUI, the WinUI project structure,
// and more about our project templates, see: http://aka.ms/winui-project-info.

namespace Baobabs;

/// <summary>
/// The application window. This hosts a Frame that displays pages. Add your
/// UI and logic to MainPage.xaml / MainPage.xaml.cs instead of here so you
/// can use Page features such as navigation events and the Loaded lifecycle.
/// </summary>
public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();

        // Extiende el contenido hacia la barra de título
        ExtendsContentIntoTitleBar = true;

        // We set the right side empty border as the primary draggable title bar
        // (WinUI 3 SetTitleBar only takes one element, but standard empty areas also drag).
        SetTitleBar(AppTitleBarRight);

        AppWindow.SetIcon("Assets/AppIcon.ico");

        // Navigate the root frame to the main page on startup.
        RootFrame.Navigate(typeof(MainPage));
    }

    private void AddressBar_KeyDown(object sender, Microsoft.UI.Xaml.Input.KeyRoutedEventArgs e)
    {
        if (e.Key == Windows.System.VirtualKey.Enter)
        {
            if (RootFrame.Content is MainPage mainPage)
            {
                mainPage.NavigateTo(AddressBar.Text);
            }
            e.Handled = true;
        }
    }
}
