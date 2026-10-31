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

        Baobabs.Models.HistoryManager.Load();
        Baobabs.Models.BookmarksManager.Load();

        HistoryList.ItemsSource = Baobabs.Models.HistoryManager.History;
        BookmarksList.ItemsSource = Baobabs.Models.BookmarksManager.Bookmarks;

        MyWebView.NavigationCompleted += MyWebView_NavigationCompleted;
        MyWebView.CoreWebView2Initialized += MyWebView_CoreWebView2Initialized;
    }

    private void SidebarTab_Checked(object sender, Microsoft.UI.Xaml.RoutedEventArgs e)
    {
        if (sender is Microsoft.UI.Xaml.Controls.RadioButton rb)
        {
            if (rb == TabBookmarks)
            {
                BookmarksList.Visibility = Microsoft.UI.Xaml.Visibility.Visible;
                ReadingListPlaceholder.Visibility = Microsoft.UI.Xaml.Visibility.Collapsed;
                HistoryList.Visibility = Microsoft.UI.Xaml.Visibility.Collapsed;
            }
            else if (rb == TabReadingList)
            {
                BookmarksList.Visibility = Microsoft.UI.Xaml.Visibility.Collapsed;
                ReadingListPlaceholder.Visibility = Microsoft.UI.Xaml.Visibility.Visible;
                HistoryList.Visibility = Microsoft.UI.Xaml.Visibility.Collapsed;
            }
            else if (rb == TabHistory)
            {
                BookmarksList.Visibility = Microsoft.UI.Xaml.Visibility.Collapsed;
                ReadingListPlaceholder.Visibility = Microsoft.UI.Xaml.Visibility.Collapsed;
                HistoryList.Visibility = Microsoft.UI.Xaml.Visibility.Visible;
            }
        }
    }

    private void SidebarList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (sender is ListView listView && listView.SelectedItem != null)
        {
            if (listView.SelectedItem is Baobabs.Models.HistoryEntry he)
            {
                NavigateTo(he.Url);
            }
            else if (listView.SelectedItem is Baobabs.Models.BookmarkEntry be)
            {
                NavigateTo(be.Url);
            }
            listView.SelectedItem = null;
        }
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
        if (args.IsSuccess && sender.CoreWebView2 != null)
        {
            string url = sender.CoreWebView2.Source;
            string title = sender.CoreWebView2.DocumentTitle;
            if (!string.IsNullOrEmpty(url))
            {
                Baobabs.Models.HistoryManager.AddEntry(url, title ?? url);
            }
        }

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
            string finalUrl = url;
            if (!finalUrl.StartsWith("http://") && !finalUrl.StartsWith("https://"))
            {
                finalUrl = "https://" + finalUrl;
            }
            MyWebView.Source = new System.Uri(finalUrl);
        }
        catch (System.Exception)
        {
            MyWebView.Source = new System.Uri("https://duckduckgo.com/?q=" + System.Uri.EscapeDataString(url));
        }
    }
}
