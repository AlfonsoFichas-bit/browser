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

        if (RootFrame.Content is MainPage mainPage)
        {
            mainPage.UrlChanged += MainPage_UrlChanged;
            mainPage.TitleChanged += MainPage_TitleChanged;
            mainPage.NavigationStateChanged += MainPage_NavigationStateChanged;
        }
    }

    private void MainPage_UrlChanged(object sender, string e)
    {
        // Don't override if the user is currently typing
        if (!AddressBar.FocusState.Equals(FocusState.Keyboard) && !AddressBar.FocusState.Equals(FocusState.Pointer))
        {
            AddressBar.Text = e;
        }
    }

    private void MainPage_TitleChanged(object sender, string e)
    {
        this.Title = string.IsNullOrWhiteSpace(e) ? "Baobabs" : $"{e} — Baobabs";
    }

    private void MainPage_NavigationStateChanged(object sender, (bool canGoBack, bool canGoForward) e)
    {
        BackButton.IsEnabled = e.canGoBack;
        ForwardButton.IsEnabled = e.canGoForward;
    }

    private void BackButton_Click(object sender, RoutedEventArgs e)
    {
        if (RootFrame.Content is MainPage mainPage)
        {
            mainPage.GoBack();
        }
    }

    private void ForwardButton_Click(object sender, RoutedEventArgs e)
    {
        if (RootFrame.Content is MainPage mainPage)
        {
            mainPage.GoForward();
        }
    }

    private void SidebarToggleButton_Click(object sender, RoutedEventArgs e)
    {
        if (RootFrame.Content is MainPage mainPage)
        {
            mainPage.ToggleSidebar();
        }
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
