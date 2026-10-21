using Gtk;

namespace Baobabs {
    public class SizeTrackingArea : Gtk.Box {
        public signal void size_changed(int width, int height);

        public override void size_allocate(int width, int height, int baseline) {
            base.size_allocate(width, height, baseline);
            size_changed(width, height);
        }
    }

    public class MainWindow : ApplicationWindow {
        private BrowserEngine engine;
        private Entry url_entry;
        private Button back_btn;
        private Button forward_btn;
        private ToggleButton sidebar_toggle;
        private SizeTrackingArea web_area;
        private FavoritesBar favorites_bar;
        private Bookmarks.Store bookmarks_store;
        private HistoryView history_view;
        private History.Store history_store;
        private bool is_loading = false;
        private string default_url = "https://duckduckgo.com";

        public MainWindow(Gtk.Application app, string? initial_url = null) {
            Object(application: app,
                   title: "Baobabs",
                   default_width: 1100,
                   default_height: 750);
            if (initial_url != null && initial_url.length > 0) {
                this.default_url = initial_url;
            }
            if (url_entry != null) {
                url_entry.text = this.default_url;
            }
        }

        construct {
            engine = create_engine();

            var header = new HeaderBar();
            header.show_title_buttons = true;
            header.add_css_class("safari-headerbar");
            set_titlebar(header);

            sidebar_toggle = new ToggleButton();
            sidebar_toggle.icon_name = "sidebar-show-symbolic";
            sidebar_toggle.tooltip_text = "Mostrar barra lateral";
            header.pack_start(sidebar_toggle);

            // Botón Atrás
            back_btn = new Button.from_icon_name("go-previous-symbolic");
            back_btn.tooltip_text = "Atrás";
            back_btn.sensitive = false;
            back_btn.clicked.connect(() => {
                engine.go_back();
            });
            header.pack_start(back_btn);

            // Botón Adelante
            forward_btn = new Button.from_icon_name("go-next-symbolic");
            forward_btn.tooltip_text = "Adelante";
            forward_btn.sensitive = false;
            forward_btn.clicked.connect(() => {
                engine.go_forward();
            });
            header.pack_start(forward_btn);

            // Barra de direcciones / búsqueda (estilo Safari)
            url_entry = new Entry();
            url_entry.hexpand = true;
            url_entry.placeholder_text = "Buscar o introducir dirección web";
            url_entry.text = this.default_url;
            url_entry.add_css_class("safari-url-entry");

            url_entry.primary_icon_name = "text-x-generic-symbolic";
            url_entry.secondary_icon_name = "view-refresh-symbolic";
            url_entry.secondary_icon_tooltip_text = "Recargar";
            url_entry.icon_press.connect((entry, pos) => {
                if (pos == EntryIconPosition.SECONDARY) {
                    if (is_loading) {
                        engine.stop();
                    } else {
                        engine.reload();
                    }
                }
            });

            url_entry.activate.connect(on_url_activated);
            header.set_title_widget(url_entry);

            // Dummy buttons on the right
            var dummy_tabs = new Button.from_icon_name("tab-new-symbolic");
            dummy_tabs.tooltip_text = "Mostrar todas las pestañas";
            header.pack_end(dummy_tabs);

            var dummy_add = new Button.from_icon_name("list-add-symbolic");
            dummy_add.tooltip_text = "Nueva pestaña";
            header.pack_end(dummy_add);

            var dummy_share = new Button.from_icon_name("emblem-shared-symbolic");
            dummy_share.tooltip_text = "Compartir";
            header.pack_end(dummy_share);

            var dummy_dl = new Button.from_icon_name("folder-download-symbolic");
            dummy_dl.tooltip_text = "Descargas";
            header.pack_end(dummy_dl);

            // Modelos
            bookmarks_store = new Bookmarks.Store();
            bookmarks_store.root = Bookmarks.Defaults.seed();
            history_store = new History.Store();
            history_store.load(Config.get_instance().history_path);
            history_store.changed.connect(() => {
                history_store.save(Config.get_instance().history_path);
            });

            // Área de visualización web
            web_area = new SizeTrackingArea();
            web_area.hexpand = true;
            web_area.vexpand = true;

            // Barra de favoritos
            favorites_bar = new FavoritesBar(bookmarks_store);
            favorites_bar.open_url.connect((url) => {
                engine.load_uri(url);
            });

            // Vista de historial
            history_view = new HistoryView(history_store);
            history_view.open_url.connect((url) => {
                engine.load_uri(url);
            });

            var sidebar_stack = new Stack();
            sidebar_stack.add_titled(favorites_bar, "favoritos", "Marcadores");
            sidebar_stack.add_titled(history_view, "historial", "Historial");

            var switcher = new StackSwitcher();
            switcher.stack = sidebar_stack;
            switcher.halign = Align.CENTER;
            switcher.margin_top = 8;
            switcher.margin_bottom = 8;

            var sidebar_box = new Box(Orientation.VERTICAL, 0);
            sidebar_box.append(switcher);
            sidebar_box.append(sidebar_stack);

            var sidebar_scrolled = new ScrolledWindow();
            sidebar_scrolled.set_child(sidebar_box);
            sidebar_scrolled.set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
            sidebar_scrolled.width_request = 250;
            sidebar_scrolled.add_css_class("sidebar-container");

            sidebar_scrolled.visible = false;
            sidebar_toggle.bind_property("active", sidebar_scrolled, "visible", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);

            var separator = new Separator(Orientation.VERTICAL);
            sidebar_toggle.bind_property("active", separator, "visible", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);

            var main_box = new Box(Orientation.HORIZONTAL, 0);
            main_box.append(sidebar_scrolled);
            main_box.append(separator);
            main_box.append(web_area);
            set_child(main_box);

            // Conectar eventos del motor
            engine.url_changed.connect((new_url) => {
                url_entry.text = new_url;
            });

            engine.title_changed.connect((new_title) => {
                if (new_title.length > 0) {
                    this.title = @"$new_title — Baobabs";
                } else {
                    this.title = "Baobabs";
                }
            });

            engine.load_state_changed.connect((state) => {
                is_loading = (state == LoadState.LOADING);
                if (is_loading) {
                    url_entry.secondary_icon_name = "process-stop-symbolic";
                    url_entry.secondary_icon_tooltip_text = "Detener";
                } else {
                    url_entry.secondary_icon_name = "view-refresh-symbolic";
                    url_entry.secondary_icon_tooltip_text = "Recargar";
                }
            });

            engine.load_finished.connect((success, error) => {
                if (!success) return;
                if (engine.url != null && engine.url.length > 0) {
                    history_store.record_visit(engine.url, engine.title);
                }
            });

            engine.notify["can-go-back"].connect(() => {
                back_btn.sensitive = engine.can_go_back;
            });

            engine.notify["can-go-forward"].connect(() => {
                forward_btn.sensitive = engine.can_go_forward;
            });
        }

        public void start() {
            engine.attach(web_area, Config.get_instance().profile_dir);
            engine.start();
            engine.load_uri(this.default_url);
        }

        private void on_url_activated() {
            string raw = url_entry.text.strip();
            if (raw.length == 0) return;

            string target = raw;
            if (!target.contains("://") && !target.has_prefix("about:")) {
                if (target.contains(".") && !target.contains(" ")) {
                    target = "https://" + target;
                } else {
                    target = "https://duckduckgo.com/?q=" + Uri.escape_string(target, "", false);
                }
            }
            engine.load_uri(target);
        }
    }
}