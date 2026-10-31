using System;
using System.Collections.ObjectModel;
using System.IO;
using System.Text.Json;
using Windows.Storage;

namespace Baobabs.Models
{
    public class HistoryEntry
    {
        public string Url { get; set; }
        public string Title { get; set; }
        public DateTime VisitTime { get; set; }
    }

    public static class HistoryManager
    {
        private static readonly string FileName = "history.json";
        public static ObservableCollection<HistoryEntry> History { get; set; } = new ObservableCollection<HistoryEntry>();

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
                    var list = JsonSerializer.Deserialize<ObservableCollection<HistoryEntry>>(json);
                    if (list != null)
                    {
                        History = list;
                    }
                }
            }
            catch
            {
                // Fallback to empty
                History = new ObservableCollection<HistoryEntry>();
            }
        }

        public static void Save()
        {
            try
            {
                var filePath = GetFilePath();
                string json = JsonSerializer.Serialize(History);
                File.WriteAllText(filePath, json);
            }
            catch
            {
                // Ignore save errors for now
            }
        }

        public static void AddEntry(string url, string title)
        {
            // Remove duplicates or old entries if necessary. For now, just insert at top.
            History.Insert(0, new HistoryEntry
            {
                Url = url,
                Title = title,
                VisitTime = DateTime.Now
            });
            Save();
        }
    }
}
