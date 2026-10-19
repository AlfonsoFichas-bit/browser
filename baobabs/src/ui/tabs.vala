using Gtk;

namespace Baobabs {
    // Pestaña = una instancia de motor + su estado de UI.
    // Una pestaña == un WebKitWebView (Safari 5.1 también creaba una
    // WebView por pestaña).
    public class Tab : GLib.Object {
        public BrowserEngine engine { get; construct; }
        public string id { get; construct; }
        public string title { get; set; default = "Nueva pestaña"; }

        public Tab(BrowserEngine engine) {
            Object(engine: engine, id: Utils.generate_uuid());
        }
    }

    // Tira de pestañas (Safari las mostraba SOLO con más de una pestaña;
    // la ventana controla la visibilidad con update_tab_visibility()).
    public class TabBar : Gtk.Box {
        public signal void tab_selected(Tab tab);
        public signal void tab_close_requested(Tab tab);

        public Gee.ArrayList<Tab> tabs { get; private set; }

        private Gee.HashMap<Tab, Gtk.ToggleButton> buttons;
        private Gee.HashMap<Tab, Gtk.Label> labels;
        private Tab? current;

        public TabBar() {
            Object(orientation: Orientation.HORIZONTAL, spacing: 0);
        }

        construct {
            tabs = new Gee.ArrayList<Tab>();
            buttons = new Gee.HashMap<Tab, Gtk.ToggleButton>();
            labels = new Gee.HashMap<Tab, Gtk.Label>();
            margin_start = 6;
            margin_end = 6;
            margin_bottom = 2;
        }

        public void add_tab(Tab tab, bool select_after) {
            tabs.add(tab);

            var btn = new ToggleButton();
            btn.add_css_class("flat");

            var box = new Box(Orientation.HORIZONTAL, 6);
            box.margin_start = 10;
            box.margin_end = 4;
            box.margin_top = 4;
            box.margin_bottom = 4;

            var label = new Label(tab.title);
            label.ellipsize = Pango.EllipsizeMode.END;
            label.max_width_chars = 18;

            var close = new Button.from_icon_name("window-close-symbolic");
            close.add_css_class("flat");
            close.tooltip_text = "Cerrar pestaña";

            box.append(label);
            box.append(close);
            btn.child = box;

            btn.toggled.connect(() => {
                if (btn.active) {
                    current = tab;
                    tab_selected(tab);
                } else if (current == tab) {
                    // la pestaña activa no se deselecciona con un clic
                    btn.active = true;
                }
            });
            close.clicked.connect(() => tab_close_requested(tab));

            buttons.set(tab, btn);
            labels.set(tab, label);
            append(btn);

            if (select_after)
                btn.active = true; // dispara tab_selected sincrónicamente
        }

        public void remove_tab(Tab tab) {
            var btn = buttons.get(tab);
            if (btn == null)
                return;
            if (current == tab)
                current = null;
            remove(btn);
            buttons.unset(tab);
            labels.unset(tab);
            tabs.remove(tab);
        }

        public void select(Tab tab) {
            current = tab;
            foreach (var t in tabs) {
                var b = buttons.get(t);
                if (b != null)
                    b.active = (t == tab);
            }
        }

        public void update_title(Tab tab) {
            var l = labels.get(tab);
            if (l != null)
                l.label = tab.title;
        }
    }
}
