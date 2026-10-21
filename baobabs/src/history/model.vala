namespace Baobabs.History {
    public class Entry : GLib.Object {
        public string url { get; set; }
        public string? title { get; set; }
        public int64 last_visited_unix { get; set; }
        public double last_visited_cocoa { get; set; }
        public int visit_count { get; set; default = 0; }
        public Gee.ArrayList<string> redirect_urls { get; construct set; }
        public Gee.ArrayList<int64?> d_value { get; construct set; }

        construct {
            redirect_urls = new Gee.ArrayList<string>();
            d_value = new Gee.ArrayList<int64?>();
            d_value.add(1);
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

        public void load(string path) {
            try {
                var root = Plist.parse_file(path);
                if (root == null || !root.is_of_type(new GLib.VariantType("a{sv}"))) return;

                var dates = root.lookup_value("WebHistoryDates", new GLib.VariantType("av"));
                if (dates == null) return;

                entries.clear();
                for (int i = 0; i < dates.n_children(); i++) {
                    var entry_v = dates.get_child_value(i).get_variant();
                    if (!entry_v.is_of_type(new GLib.VariantType("a{sv}"))) continue;

                    var entry = new Entry();

                    var url_v = entry_v.lookup_value("", new GLib.VariantType("s"));
                    if (url_v != null) entry.url = url_v.get_string();
                    else continue; // URL is required

                    var title_v = entry_v.lookup_value("title", new GLib.VariantType("s"));
                    if (title_v != null) entry.title = title_v.get_string();

                    var last_visited_v = entry_v.lookup_value("lastVisitedDate", new GLib.VariantType("s"));
                    if (last_visited_v != null) {
                        entry.last_visited_cocoa = double.parse(last_visited_v.get_string());
                        entry.last_visited_unix = EpochUtils.cocoa_to_unix(entry.last_visited_cocoa);
                    }

                    var count_v = entry_v.lookup_value("visitCount", new GLib.VariantType("x"));
                    if (count_v != null) entry.visit_count = (int)count_v.get_int64();

                    var redirects_v = entry_v.lookup_value("redirectURLs", new GLib.VariantType("av"));
                    if (redirects_v != null) {
                        entry.redirect_urls.clear();
                        for (int j = 0; j < redirects_v.n_children(); j++) {
                            var rv = redirects_v.get_child_value(j).get_variant();
                            if (rv.is_of_type(new GLib.VariantType("s"))) {
                                entry.redirect_urls.add(rv.get_string());
                            }
                        }
                    }

                    var d_v = entry_v.lookup_value("D", new GLib.VariantType("av"));
                    if (d_v != null) {
                        entry.d_value.clear();
                        for (int j = 0; j < d_v.n_children(); j++) {
                            var dv_item = d_v.get_child_value(j).get_variant();
                            if (dv_item.is_of_type(new GLib.VariantType("x"))) {
                                entry.d_value.add(dv_item.get_int64());
                            }
                        }
                    }

                    entries.set(entry.url, entry);
                }
                this.changed();
            } catch (GLib.Error e) {
                // If the file doesn't exist or is corrupt, simply keep the memory store empty and don't abort.
                warning("Failed to load history: %s", e.message);
            }
        }

        public void save(string path) {
            var db = new GLib.VariantBuilder(new GLib.VariantType("a{sv}"));
            db.add("{sv}", "WebHistoryFileVersion", new GLib.Variant.int64(1));

            var ab = new GLib.VariantBuilder(new GLib.VariantType("av"));
            foreach (var entry in entries.values) {
                var eb = new GLib.VariantBuilder(new GLib.VariantType("a{sv}"));
                eb.add("{sv}", "", new GLib.Variant.string(entry.url));
                if (entry.title != null && entry.title.length > 0) {
                    eb.add("{sv}", "title", new GLib.Variant.string(entry.title));
                }

                string date_str = "%.15g".printf(entry.last_visited_cocoa);
                eb.add("{sv}", "lastVisitedDate", new GLib.Variant.string(date_str));

                eb.add("{sv}", "visitCount", new GLib.Variant.int64(entry.visit_count));

                if (entry.redirect_urls.size > 0) {
                    var rb = new GLib.VariantBuilder(new GLib.VariantType("av"));
                    foreach (var url in entry.redirect_urls) {
                        rb.add_value(new GLib.Variant.variant(new GLib.Variant.string(url)));
                    }
                    eb.add("{sv}", "redirectURLs", rb.end());
                }

                if (entry.d_value.size > 0) {
                    var d_arr = new GLib.VariantBuilder(new GLib.VariantType("av"));
                    foreach (var val in entry.d_value) {
                        d_arr.add_value(new GLib.Variant.variant(new GLib.Variant.int64(val)));
                    }
                    eb.add("{sv}", "D", d_arr.end());
                }

                ab.add_value(new GLib.Variant.variant(eb.end()));
            }
            db.add("{sv}", "WebHistoryDates", ab.end());

            try {
                PlistWriter.write_file(path, db.end());
            } catch (GLib.Error e) {
                warning("Failed to save history: %s", e.message);
            }
        }

        public signal void changed();
    }
}