using Microsoft.UI.Xaml.Controls;

// To learn more about WinUI, the WinUI project structure,
// and more about our project templates, see: http://aka.ms/winui-project-info.

namespace Baobabs;

/// <summary>
/// The main content page displayed inside the application window.
/// Add your UI logic, event handlers, and data binding here.
/// </summary>
public sealed partial class MainPage : Page
{
    public event System.EventHandler<string> UrlChanged;
    public event System.EventHandler<string> TitleChanged;
    public event System.EventHandler<(bool canGoBack, bool canGoForward)> NavigationStateChanged;

    public MainPage()
    {
        InitializeComponent();

        MyWebView.NavigationCompleted += MyWebView_NavigationCompleted;
        MyWebView.CoreWebView2Initialized += MyWebView_CoreWebView2Initialized;
    }

    private void MyWebView_CoreWebView2Initialized(Microsoft.UI.Xaml.Controls.WebView2 sender, Microsoft.UI.Xaml.Controls.CoreWebView2InitializedEventArgs args)
    {
        MyWebView.CoreWebView2.SourceChanged += CoreWebView2_SourceChanged;
        MyWebView.CoreWebView2.DocumentTitleChanged += CoreWebView2_DocumentTitleChanged;
        MyWebView.CoreWebView2.HistoryChanged += CoreWebView2_HistoryChanged;
    }

    private void CoreWebView2_SourceChanged(Microsoft.Web.WebView2.Core.CoreWebView2 sender, Microsoft.Web.WebView2.Core.CoreWebView2SourceChangedEventArgs args)
    {
        UrlChanged?.Invoke(this, sender.Source);
    }

    private void CoreWebView2_DocumentTitleChanged(Microsoft.Web.WebView2.Core.CoreWebView2 sender, object args)
    {
        TitleChanged?.Invoke(this, sender.DocumentTitle);
    }

    private void CoreWebView2_HistoryChanged(Microsoft.Web.WebView2.Core.CoreWebView2 sender, object args)
    {
        NavigationStateChanged?.Invoke(this, (sender.CanGoBack, sender.CanGoForward));
    }

    private void MyWebView_NavigationCompleted(Microsoft.UI.Xaml.Controls.WebView2 sender, Microsoft.Web.WebView2.Core.CoreWebView2NavigationCompletedEventArgs args)
    {
        // Fallback for updating state if HistoryChanged missed something
        NavigationStateChanged?.Invoke(this, (MyWebView.CanGoBack, MyWebView.CanGoForward));
    }

    public void GoBack()
    {
        if (MyWebView.CanGoBack)
        {
            MyWebView.GoBack();
        }
    }

    public void GoForward()
    {
        if (MyWebView.CanGoForward)
        {
            MyWebView.GoForward();
        }
    }

    public void ToggleSidebar()
    {
        SidebarContainer.Visibility = SidebarContainer.Visibility == Microsoft.UI.Xaml.Visibility.Visible
            ? Microsoft.UI.Xaml.Visibility.Collapsed
            : Microsoft.UI.Xaml.Visibility.Visible;
    }

    public void NavigateTo(string url)
    {
        try
        {
            if (!url.StartsWith("http://") && !url.StartsWith("https://"))
            {
                url = "https://" + url;
            }
            MyWebView.Source = new System.Uri(url);
        }
        catch (System.Exception)
        {
            MyWebView.Source = new System.Uri("https://duckduckgo.com/?q=" + System.Uri.EscapeDataString(url));
        }
    }
}
