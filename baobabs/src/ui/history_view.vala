using Gtk;

namespace Baobabs {
    public class HistoryView : Gtk.Box {
        public signal void open_url(string url);

        private History.Store store;
        private Gtk.Box content_box;

        private const string[] DIAS = {
            "Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"
        };
        private const string[] MESES = {
            "enero", "febrero", "marzo", "abril", "mayo", "junio",
            "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"
        };

        private string fecha_en_espanol(GLib.DateTime d) {
            int y, m, dd;
            d.get_ymd(out y, out m, out dd);
            int wd = d.get_day_of_week();
            return "%s, %d de %s".printf(DIAS[wd % 7], dd, MESES[m - 1]);
        }

        public HistoryView(History.Store store) {
            Object(orientation: Orientation.VERTICAL, spacing: 4);
            this.store = store;
            this.vexpand = true;

            content_box = new Gtk.Box(Orientation.VERTICAL, 4);
            content_box.margin_top = 8;
            content_box.margin_bottom = 8;
            content_box.margin_start = 8;
            content_box.margin_end = 8;
            this.append(content_box);

            this.store.changed.connect(rebuild_ui);
            rebuild_ui();
        }

        private void rebuild_ui() {
            // Limpiar contenido existente
            var child = content_box.get_first_child();
            while (child != null) {
                var next = child.get_next_sibling();
                content_box.remove(child);
                child = next;
            }

            if (store.entries.size == 0) {
                var empty_label = new Label("Sin historial");
                empty_label.add_css_class("history-empty");
                empty_label.halign = Align.CENTER;
                empty_label.valign = Align.CENTER;
                empty_label.vexpand = true;
                content_box.append(empty_label);
                return;
            }

            // Obtener todas las entradas y ordenarlas
            var list = new Gee.ArrayList<History.Entry>();
            foreach (var entry in store.entries.values) {
                list.add(entry);
            }

            // Orden descendente (más reciente primero)
            list.sort((a, b) => {
                if (a.last_visited_unix > b.last_visited_unix) return -1;
                if (a.last_visited_unix < b.last_visited_unix) return 1;
                return 0;
            });

            var now = new GLib.DateTime.now_local();
            int ny, nm, nd;
            now.get_ymd(out ny, out nm, out nd);

            var yesterday = now.add_days(-1);
            int yy, ym, yd;
            yesterday.get_ymd(out yy, out ym, out yd);

            string current_group = "";

            foreach (var entry in list) {
                var visited = new GLib.DateTime.from_unix_local(entry.last_visited_unix);
                int vy, vm, vd;
                visited.get_ymd(out vy, out vm, out vd);

                string group_title = "";
                if (ny == vy && nm == vm && nd == vd) {
                    group_title = "Hoy";
                } else if (yy == vy && ym == vm && yd == vd) {
                    group_title = "Ayer";
                } else {
                    group_title = fecha_en_espanol(visited);
                }

                if (group_title != current_group) {
                    var header = new Label(group_title);
                    header.add_css_class("history-date-header");
                    header.halign = Align.START;
                    header.margin_top = 8;
                    header.margin_bottom = 2;
                    content_box.append(header);
                    current_group = group_title;
                }

                string display_text = entry.title != null && entry.title.length > 0 ? entry.title : entry.url;

                var btn = new Button.with_label(display_text);
                btn.add_css_class("history-item");
                btn.halign = Align.FILL;

                var label = btn.get_child() as Label;
                if (label != null) {
                    label.halign = Align.START;
                    label.ellipsize = Pango.EllipsizeMode.END;
                }

                string url_to_open = entry.url;
                btn.clicked.connect(() => {
                    open_url(url_to_open);
                });

                content_box.append(btn);
            }
        }
    }
}
