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

    // Historial con el esquema de Safari 5.1 (HABITAT.md 1.3):
    //   { WebHistoryFileVersion: 1,
    //     WebHistoryDates: { URL: { title, lastVisitedDate (epoch Cocoa),
    //                                visitCount, redirectURLs } } }
    public class Store : GLib.Object {
        public Gee.HashMap<string, Entry> entries { get; construct set; }

        construct {
            entries = new Gee.HashMap<string, Entry>();
        }

        public signal void changed();

        public void record_visit(string url, string? title) {
            var entry = entries.get(url);
            var now = new GLib.DateTime.now_utc();
            if (entry == null) {
                entry = new Entry();
                entry.url = url;
                entry.visit_count = 1;
                entries.set(url, entry);
            } else {
                entry.visit_count++;
            }
            entry.last_visited_unix = now.to_unix();
            entry.last_visited_cocoa =
                EpochUtils.unix_to_cocoa(entry.last_visited_unix);
            if (title != null && title != "" && entry.title != title)
                entry.title = title;
            this.changed();
        }

        // Lectura tolerante: fichero ausente o corrupto = historial vacío
        // (nunca lanza; la ventana decide qué avisar).
        public void load_from_file(string path) {
            if (!FileUtils.test(path, FileTest.EXISTS))
                return;
            try {
                var root = Plist.parse_file(path);
                if (!root.is_of_type(new VariantType("a{sv}"))) {
                    warning("History: la raíz de %s no es un dict", path);
                    return;
                }
                var dates = root.lookup_value("WebHistoryDates",
                                              new VariantType("a{sv}"));
                if (dates == null)
                    return;
                for (size_t i = 0; i < dates.n_children(); i++) {
                    // entradas del dict: pares {sv}
                    var pair = dates.get_child_value(i);
                    string url = pair.get_child_value(0).get_string();
                    var d = pair.get_child_value(1);
                    if (!d.is_of_type(new VariantType("a{sv}")))
                        continue;
                    var e = new Entry();
                    e.url = url;
                    var t = d.lookup_value("title", VariantType.STRING);
                    if (t != null)
                        e.title = t.get_string();
                    var lvd = d.lookup_value("lastVisitedDate",
                                             VariantType.DOUBLE);
                    if (lvd != null) {
                        e.last_visited_cocoa = lvd.get_double();
                        e.last_visited_unix =
                            EpochUtils.cocoa_to_unix(e.last_visited_cocoa);
                    }
                    var vc = d.lookup_value("visitCount", VariantType.INT64);
                    if (vc != null)
                        e.visit_count = (int)vc.get_int64();
                    var rl = d.lookup_value("redirectURLs",
                                            new VariantType("av"));
                    if (rl != null) {
                        for (size_t j = 0; j < rl.n_children(); j++) {
                            e.redirect_urls.add(
                                rl.get_child_value(j).get_variant()
                                  .get_string());
                        }
                    }
                    entries.set(url, e);
                }
            } catch (Error e) {
                warning("History: no se pudo leer %s: %s", path, e.message);
            }
        }

        public void save_to_file(string path) throws GLib.Error {
            var dates = new VariantBuilder(new VariantType("a{sv}"));
            foreach (var e in entries.values) {
                var d = new VariantBuilder(new VariantType("a{sv}"));
                d.add("{sv}", "title", new Variant.string(e.title ?? ""));
                d.add("{sv}", "lastVisitedDate",
                      new Variant.double(e.last_visited_cocoa));
                d.add("{sv}", "visitCount",
                      new Variant.int64(e.visit_count));
                var r = new VariantBuilder(new VariantType("av"));
                foreach (var u in e.redirect_urls)
                    r.add_value(new Variant.string(u));
                d.add("{sv}", "redirectURLs", r.end());
                dates.add("{sv}", e.url, d.end());
            }
            var root = new VariantBuilder(new VariantType("a{sv}"));
            root.add("{sv}", "WebHistoryFileVersion",
                     new Variant.int64(1));
            root.add("{sv}", "WebHistoryDates", dates.end());
            var bytes = PlistWriter.to_bytes(root.end());
            FileUtils.set_data(path, bytes);
        }
    }
}
