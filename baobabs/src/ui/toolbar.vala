using Gtk;

namespace Baobabs {
    // Barra de herramientas estilo Safari 5.1:
    //   [atrás][adelante][recargar] [==== dirección ====] [+] [menú]
    // Se usa como title_widget del HeaderBar (centrada, con la ventana
    // repartida a los lados por GTK).
    public class Toolbar : Gtk.Box {
        public Gtk.Button btn_back { get; private set; }
        public Gtk.Button btn_forward { get; private set; }
        public Gtk.Button btn_reload { get; private set; }
        public Gtk.Entry entry_url { get; private set; }
        public Gtk.Button btn_new_tab { get; private set; }
        public Gtk.MenuButton btn_menu { get; private set; }

        public signal void url_submitted(string text);

        public Toolbar() {
            Object(orientation: Orientation.HORIZONTAL, spacing: 4);
        }

        construct {
            hexpand = true;
            margin_start = 6;
            margin_end = 6;
            margin_top = 4;
            margin_bottom = 4;

            btn_back = new Button.from_icon_name("go-previous-symbolic");
            btn_back.tooltip_text = "Atrás (Alt+←)";
            btn_back.add_css_class("flat");
            btn_back.sensitive = false;

            btn_forward = new Button.from_icon_name("go-next-symbolic");
            btn_forward.tooltip_text = "Adelante (Alt+→)";
            btn_forward.add_css_class("flat");
            btn_forward.sensitive = false;

            btn_reload = new Button.from_icon_name("view-refresh-symbolic");
            btn_reload.tooltip_text = "Recargar (Ctrl+R)";
            btn_reload.add_css_class("flat");

            entry_url = new Entry();
            entry_url.hexpand = true;
            entry_url.placeholder_text =
                "Buscar o introducir una dirección web";
            entry_url.activate.connect(() => url_submitted(entry_url.text));

            btn_new_tab = new Button.from_icon_name("list-add-symbolic");
            btn_new_tab.tooltip_text = "Nueva pestaña (Ctrl+T)";
            btn_new_tab.add_css_class("flat");

            btn_menu = new MenuButton();
            btn_menu.icon_name = "open-menu-symbolic";
            btn_menu.tooltip_text = "Menú";
            btn_menu.add_css_class("flat");

            append(btn_back);
            append(btn_forward);
            append(btn_reload);
            append(entry_url);
            append(btn_new_tab);
            append(btn_menu);
        }

        public void set_url(string u) {
            if (entry_url.text != u)
                entry_url.text = u;
        }

        public void focus_url(bool select_all) {
            entry_url.grab_focus();
            if (select_all)
                entry_url.select_region(0, -1);
        }

        public void set_loading(bool loading) {
            btn_reload.icon_name = loading
                ? "process-stop-symbolic"
                : "view-refresh-symbolic";
            btn_reload.tooltip_text = loading
                ? "Detener (Esc)"
                : "Recargar (Ctrl+R)";
        }

        // Estado completo de navegación; la ventana lo llama al cambiar de
        // pestaña y en load_started/load_finished.
        public void set_nav_state(bool back, bool forward, bool loading) {
            btn_back.sensitive = back;
            btn_forward.sensitive = forward;
            set_loading(loading);
        }
    }
}
