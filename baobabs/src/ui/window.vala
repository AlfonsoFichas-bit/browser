using Gtk;

namespace Baobabs {
    // Ventana principal: barra de herramientas (HeaderBar), tira de pestañas,
    // barra de progreso y contenido (una pestaña = un motor = un widget).
    public class MainWindow : ApplicationWindow {
        Config config;
        History.Store history;
        Bookmarks.Node? bookmarks_root;

        Toolbar toolbar;
        TabBar tab_bar;
        Gtk.Stack content;
        Gtk.Revealer progress_revealer;
        Gtk.ProgressBar progress;
        Gtk.Overlay overlay;
        Gtk.Box main_box;
        Gtk.Revealer status_revealer;
        Gtk.Label status_label;
        GLib.Menu menu_model;
        Tab? active_tab = null;

        public MainWindow(Gtk.Application app) {
            Object(application: app,
                   title: "Baobabs",
                   default_width: 1024,
                   default_height: 768);
        }

        construct {
            config = Config.get_instance();
            history = new History.Store();
            history.changed.connect(rebuild_menu);
            history.load_from_file(config.history_path);
            bookmarks_root = load_bookmarks();

            // --- Barra superior ---
            toolbar = new Toolbar();
            var header = new HeaderBar();
            header.show_title_buttons = true;
            header.title_widget = toolbar;
            set_titlebar(header);

            // --- Pestañas ---
            tab_bar = new TabBar();
            tab_bar.visible = false; // solo con >1 pestaña (como Safari)
            tab_bar.tab_selected.connect(select_tab);
            tab_bar.tab_close_requested.connect(close_tab);

            // --- Progreso (bajo la cabecera, como la barra de Safari) ---
            progress = new ProgressBar();
            progress.height_request = 2;
            progress_revealer = new Revealer();
            progress_revealer.transition_type =
                RevealerTransitionType.SLIDE_DOWN;
            progress_revealer.child = progress;

            // --- Contenido ---
            content = new Stack();
            content.transition_type = StackTransitionType.CROSSFADE;
            content.transition_duration = 120;

            // --- Barra de estado (fallback sin Granite) ---
            status_label = new Label("");
            status_label.xalign = 0;
            status_label.margin_start = 8;
            status_label.margin_end = 8;
            status_label.margin_top = 4;
            status_label.margin_bottom = 4;
            status_revealer = new Revealer();
            status_revealer.transition_type =
                RevealerTransitionType.SLIDE_UP;
            status_revealer.child = status_label;

            main_box = new Box(Orientation.VERTICAL, 0);
            main_box.append(progress_revealer);
            main_box.append(tab_bar);
            main_box.append(content);
            main_box.append(status_revealer);

            overlay = new Overlay();
            overlay.child = main_box;
            set_child(overlay);

            // --- Acciones, menú y primera pestaña ---
            setup_actions();
            menu_model = new GLib.Menu();
            toolbar.btn_menu.menu_model = menu_model;
            wire_toolbar();
            rebuild_menu();

            open_tab(null);
        }

        // ------------------------------------------------------------------
        // Acciones (los aceleradores los asigna App)
        // ------------------------------------------------------------------
        void setup_actions() {
            add_action(simple("new-tab", () => open_tab(null)));
            add_action(simple("close-tab", () => {
                if (active_tab != null)
                    close_tab(active_tab);
            }));
            add_action(simple("focus-address", () => toolbar.focus_url(true)));
            add_action(simple("reload", toggle_reload));
            add_action(simple("go-back", go_back));
            add_action(simple("go-forward", go_forward));
            add_action(simple("quit", () => close()));

            var open_url = new GLib.SimpleAction("open-url",
                                                 new VariantType("s"));
            open_url.activate.connect((p) => {
                if (p != null)
                    open_tab(p.get_string());
            });
            add_action(open_url);
        }

        GLib.SimpleAction simple(string name, owned ActionHandler handler) {
            var a = new GLib.SimpleAction(name, null);
            a.activate.connect(() => handler());
            return a;
        }

        public delegate void ActionHandler();

        void wire_toolbar() {
            toolbar.btn_back.clicked.connect(go_back);
            toolbar.btn_forward.clicked.connect(go_forward);
            toolbar.btn_reload.clicked.connect(toggle_reload);
            toolbar.btn_new_tab.clicked.connect(() => open_tab(null));
            toolbar.url_submitted.connect((text) => {
                if (active_tab == null)
                    return;
                var uri = Utils.normalize_input(text);
                if (uri == "")
                    return;
                active_tab.engine.load_uri(uri);
                active_tab.engine.focus();
            });
        }

        void go_back() {
            if (active_tab != null)
                active_tab.engine.go_back();
        }

        void go_forward() {
            if (active_tab != null)
                active_tab.engine.go_forward();
        }

        void toggle_reload() {
            if (active_tab == null)
                return;
            var e = active_tab.engine;
            if (e.can_stop)
                e.stop();
            else
                e.reload();
        }

        // ------------------------------------------------------------------
        // Pestañas
        // ------------------------------------------------------------------
        public Tab open_tab(string? uri) {
            var engine = Baobabs.create_engine();
            var tab = new Tab(engine);
            wire_tab(tab);
            content.add_named(engine.get_widget(), tab.id);
            tab_bar.add_tab(tab, true); // dispara select_tab
            if (uri != null && uri != "")
                engine.load_uri(Utils.normalize_input(uri));
            update_tab_visibility();
            return tab;
        }

        void select_tab(Tab tab) {
            active_tab = tab;
            var e = tab.engine;
            content.visible_child = e.get_widget();
            tab_bar.select(tab);
            toolbar.set_url(e.url);
            toolbar.set_nav_state(e.can_go_back, e.can_go_forward, e.can_stop);
            update_window_title();
            e.focus();
        }

        void close_tab(Tab tab) {
            bool was_active = (tab == active_tab);
            int idx = tab_bar.tabs.index_of(tab);
            tab_bar.remove_tab(tab);
            content.remove(tab.engine.get_widget());
            update_tab_visibility();

            if (tab_bar.tabs.size == 0) {
                close(); // sin pestañas: la ventana se cierra (la app sale)
                return;
            }
            if (was_active) {
                int new_idx = idx;
                if (new_idx >= tab_bar.tabs.size)
                    new_idx = tab_bar.tabs.size - 1;
                if (new_idx < 0)
                    new_idx = 0;
                select_tab(tab_bar.tabs[new_idx]);
            }
        }

        void update_tab_visibility() {
            tab_bar.visible = tab_bar.tabs.size > 1;
        }

        // ------------------------------------------------------------------
        // Señales del motor de cada pestaña
        // ------------------------------------------------------------------
        void wire_tab(Tab tab) {
            var e = tab.engine;

            e.load_started.connect(() => {
                if (tab != active_tab)
                    return;
                progress_revealer.reveal_child = true;
                progress.fraction = 0.0;
                toolbar.set_nav_state(e.can_go_back, e.can_go_forward, true);
            });

            e.load_finished.connect((ok, err) => {
                if (ok) {
                    record_visit(e.url, e.title);
                } else if (err != null && tab == active_tab) {
                    show_message(err);
                }
                if (tab == active_tab) {
                    progress_revealer.reveal_child = false;
                    toolbar.set_nav_state(e.can_go_back, e.can_go_forward,
                                          false);
                }
            });

            e.progress_changed.connect((p) => {
                if (tab == active_tab)
                    progress.fraction = p;
            });

            e.url_changed.connect(() => {
                if (tab != active_tab)
                    return;
                // no pisar lo que el usuario está tecleando
                if (!toolbar.entry_url.has_focus)
                    toolbar.set_url(e.url);
                refresh_tab_title(tab);
            });

            e.title_changed.connect(() => refresh_tab_title(tab));

            // popup → pestaña nueva (igual que Safari)
            e.new_window_requested.connect((u) => open_tab(u));
        }

        void refresh_tab_title(Tab tab) {
            var t = tab.engine.title;
            if (t == null || t.strip() == "")
                t = Utils.host_of(tab.engine.url);
            if (t == null || t == "")
                t = "Nueva pestaña";
            if (tab.title == t)
                return;
            tab.title = t;
            tab_bar.update_title(tab);
            if (tab == active_tab)
                update_window_title();
        }

        void update_window_title() {
            if (active_tab == null) {
                title = "Baobabs";
                return;
            }
            var t = active_tab.title;
            if (t == null || t == "" || t == "Nueva pestaña")
                title = "Baobabs";
            else
                title = "%s — Baobabs".printf(t);
        }

        // ------------------------------------------------------------------
        // Historial (solo navegaciones web reales; about:/data: no cuentan)
        // ------------------------------------------------------------------
        void record_visit(string url, string? page_title) {
            if (!(url.has_prefix("http://") || url.has_prefix("https://")
                  || url.has_prefix("file://")))
                return;
            history.record_visit(url, page_title);
            try {
                history.save_to_file(config.history_path);
            } catch (Error e) {
                warning("History: no se pudo guardar: %s", e.message);
            }
        }

        // ------------------------------------------------------------------
        // Menú (marcadores + historial + utilidades)
        // ------------------------------------------------------------------
        Bookmarks.Node? load_bookmarks() {
            try {
                return Bookmarks.Loader.from_file(config.bookmarks_path);
            } catch (Error e) {
                // Perfil nuevo sin Bookmarks.plist todavía: sección vacía
                return null;
            }
        }

        void rebuild_menu() {
            menu_model.remove_all();

            var bm = new GLib.Menu();
            if (bookmarks_root != null)
                fill_bookmarks(bm, bookmarks_root);
            if (bm.get_n_items() == 0)
                bm.append("Sin marcadores", null);
            menu_model.append_section("Marcadores", bm);

            var hm = new GLib.Menu();
            int n = 0;
            foreach (var e in sorted_history()) {
                if (n++ >= 15)
                    break;
                var label = (e.title != null && e.title != "") ? e.title : e.url;
                var item = new GLib.MenuItem(label, null);
                item.set_action_and_target_value("win.open-url",
                                                 new Variant.string(e.url));
                hm.append_item(item);
            }
            if (hm.get_n_items() == 0)
                hm.append("Sin historial", null);
            menu_model.append_section("Historial", hm);

            var um = new GLib.Menu();
            um.append("Nueva pestaña", "win.new-tab");
            um.append("Salir", "win.quit");
            menu_model.append_section(null, um);
        }

        void fill_bookmarks(GLib.Menu menu, Bookmarks.Node node) {
            foreach (var c in node.children) {
                if (c.node_type == Bookmarks.NodeType.LEAF && c.url != null) {
                    var label = (c.title != null && c.title != "") ? c.title
                                                                  : c.url;
                    var item = new GLib.MenuItem(label, null);
                    item.set_action_and_target_value("win.open-url",
                                                     new Variant.string(c.url));
                    menu.append_item(item);
                } else if (c.node_type == Bookmarks.NodeType.LIST
                           && c.children.size > 0) {
                    var sub = new GLib.Menu();
                    fill_bookmarks(sub, c);
                    menu.append_submenu(c.title ?? "Carpeta", sub);
                }
            }
        }

        Gee.ArrayList<History.Entry> sorted_history() {
            var list = new Gee.ArrayList<History.Entry>();
            foreach (var e in history.entries.values)
                list.add(e);
            list.sort((a, b) => {
                if (a.last_visited_unix < b.last_visited_unix)
                    return 1;
                return a.last_visited_unix > b.last_visited_unix ? -1 : 0;
            });
            return list;
        }

        // ------------------------------------------------------------------
        // Avisos
        // ------------------------------------------------------------------
        void show_message(string message) {
#if HAVE_GRANITE
            var toast = new Granite.Toast(message);
            overlay.add_overlay(toast);
            toast.dismissed.connect(() => overlay.remove_overlay(toast));
            toast.send_notification();
#else
            status_label.label = message;
            status_revealer.reveal_child = true;
            GLib.Timeout.add_seconds(6, () => {
                status_revealer.reveal_child = false;
                return GLib.Source.REMOVE;
            });
#endif
        }
    }
}
