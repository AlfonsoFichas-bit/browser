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
        private Button reload_btn;
        private SizeTrackingArea web_area;
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
            set_titlebar(header);

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

            // Botón Recargar / Detener
            reload_btn = new Button.from_icon_name("view-refresh-symbolic");
            reload_btn.tooltip_text = "Recargar";
            reload_btn.clicked.connect(() => {
                if (is_loading) {
                    engine.stop();
                } else {
                    engine.reload();
                }
            });
            header.pack_start(reload_btn);

            // Barra de direcciones / búsqueda (estilo Safari)
            url_entry = new Entry();
            url_entry.hexpand = true;
            url_entry.placeholder_text = "Buscar o introducir dirección web";
            url_entry.text = this.default_url;
            url_entry.activate.connect(on_url_activated);
            header.set_title_widget(url_entry);

            // Área de visualización web
            web_area = new SizeTrackingArea();
            web_area.hexpand = true;
            web_area.vexpand = true;

            var box = new Box(Orientation.VERTICAL, 0);
            box.append(web_area);
            set_child(box);

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
                    reload_btn.icon_name = "process-stop-symbolic";
                    reload_btn.tooltip_text = "Detener";
                } else {
                    reload_btn.icon_name = "view-refresh-symbolic";
                    reload_btn.tooltip_text = "Recargar";
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
            web_area.grab_focus();
        }
    }
}