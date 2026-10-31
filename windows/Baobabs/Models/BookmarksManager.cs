using System.Collections.ObjectModel;
using System.IO;
using System.Text.Json;
using Windows.Storage;

namespace Baobabs.Models
{
    public class BookmarkEntry
    {
        public string Url { get; set; }
        public string Title { get; set; }
    }

    public static class BookmarksManager
    {
        private static readonly string FileName = "bookmarks.json";
        public static ObservableCollection<BookmarkEntry> Bookmarks { get; set; } = new ObservableCollection<BookmarkEntry>();

        private static string GetFilePath()
        {
            try
            {
                return Path.Combine(ApplicationData.Current.LocalFolder.Path, FileName);
            }
            catch
            {
                // Fallback for unpackaged execution
                var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                var appFolder = Path.Combine(localAppData, "Baobabs");
                Directory.CreateDirectory(appFolder);
                return Path.Combine(appFolder, FileName);
            }
        }

        public static void Load()
        {
            try
            {
                var filePath = GetFilePath();
                if (File.Exists(filePath))
                {
                    string json = File.ReadAllText(filePath);
                    var list = JsonSerializer.Deserialize<ObservableCollection<BookmarkEntry>>(json);
                    if (list != null)
                    {
                        Bookmarks = list;
                    }
                }
            }
            catch
            {
                Bookmarks = new ObservableCollection<BookmarkEntry>();
            }
        }

        public static void Save()
        {
            try
            {
                var filePath = GetFilePath();
                string json = JsonSerializer.Serialize(Bookmarks);
                File.WriteAllText(filePath, json);
            }
            catch
            {
                // Ignore save errors for now
            }
        }
    }
}
