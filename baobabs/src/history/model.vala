namespace Baobabs.History {
    public class Entry : GLib.Object {
        public string url { get; set; }
        public string? title { get; set; }
        public int64 last_visited_unix { get; set; }
        public double last_visited_cocoa { get; set; }
        public int visit_count { get; set; default = 0; }
        public Gee.ArrayList<string> redirect_urls { get; construct set; }

        construct {
            redirect_urls = new Gee.ArrayList<string>();
        }
    }

    public class Store : GLib.Object {
        public Gee.HashMap<string, Entry> entries { get; construct set; }

        construct {
            entries = new Gee.HashMap<string, Entry>();
        }

        public void record_visit(string url, string? title) {
            var entry = entries.get(url);
            if (entry == null) {
                entry = new Entry();
                entry.url = url;
                entry.title = title;
                entry.visit_count = 1;
                var now = new GLib.DateTime.now_utc();
                entry.last_visited_unix = now.to_unix();
                entry.last_visited_cocoa = EpochUtils.unix_to_cocoa(entry.last_visited_unix);
                entries.set(url, entry);
            } else {
                entry.visit_count++;
                var now = new GLib.DateTime.now_utc();
                entry.last_visited_unix = now.to_unix();
                entry.last_visited_cocoa = EpochUtils.unix_to_cocoa(entry.last_visited_unix);
                if (title != null && entry.title == null) {
                    entry.title = title;
                }
            }
            this.changed();
        }

        public signal void changed();
    }
}