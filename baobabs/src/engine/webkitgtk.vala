// Backend WebKitGTK 6 (GTK4) — plataforma Linux.
// Todas las firmas están verificadas contra webkitgtk-6.0.vapi del sistema.

namespace Baobabs {
    public class WebKitGtkEngine : GLib.Object, BrowserEngine {
        WebKit.WebView web_view;
        string _url = "";
        string _title = "";
        // Evita emitir load_finished(true) si ya hubo load_failed para la
        // misma navegación (WebKit emite ambos eventos al fallar).
        bool failed = false;

        public string url {
            get { return _url; }
            set { load_uri(value); }
        }

        public string title {
            get { return _title; }
            set { /* el título lo decide la página; setter es no-op */ }
        }

        public double zoom {
            get { return web_view.get_zoom_level(); }
            set { web_view.set_zoom_level(value); }
        }

        public bool can_go_back { get { return web_view.can_go_back(); } }
        public bool can_go_forward { get { return web_view.can_go_forward(); } }
        public bool can_reload { get { return !web_view.is_loading; } }
        public bool can_stop { get { return web_view.is_loading; } }

        public WebKitGtkEngine() {
            Object();
        }

        construct {
            web_view = new WebKit.WebView();
            web_view.hexpand = true;
            web_view.vexpand = true;

            var settings = web_view.get_settings();
            settings.enable_developer_extras = true;

            web_view.notify["uri"].connect(() => {
                _url = web_view.get_uri() ?? _url;
                url_changed(_url);
            });

            web_view.notify["title"].connect(() => {
                _title = web_view.get_title() ?? "";
                title_changed(_title);
            });

            web_view.notify["estimated-load-progress"].connect(() => {
                progress_changed(web_view.get_estimated_load_progress());
            });

            web_view.load_changed.connect((ev) => {
                if (ev == WebKit.LoadEvent.STARTED) {
                    failed = false;
                    load_started(_url);
                    load_state_changed(LoadState.LOADING);
                } else if (ev == WebKit.LoadEvent.FINISHED) {
                    if (failed)
                        return; // load_finished ya emitido por load_failed
                    load_finished(true, null);
                    load_state_changed(LoadState.FINISHED);
                    progress_changed(1.0);
                }
            });

            web_view.load_failed.connect((ev, failing_uri, err) => {
                // La cancelación al navegar es normal (usuario fue a otra URL)
                if (err is GLib.IOError.CANCELLED)
                    return false;
                failed = true;
                load_finished(false, err.message);
                load_state_changed(LoadState.FAILED);
                // false: que WebKit muestre su página de error por defecto
                return false;
            });

            web_view.decide_policy.connect((decision, type) => {
                if (type == WebKit.PolicyDecisionType.RESPONSE)
                    return false; // descargas/mime: manejo por defecto

                var nav = decision as WebKit.NavigationPolicyDecision;
                if (nav == null)
                    return false;
                string? uri = nav.get_navigation_action().get_request().get_uri();
                if (uri == null)
                    return false;

                // Esquemas internos de Safari (HABITAT.md 1.7): reservados.
                // topsites:// llegará en la fase 2 con su vista nativa.
                if (uri.has_prefix("topsites:") || uri.has_prefix("safari-resource:")) {
                    decision.ignore();
                    load_finished(false,
                        "Esquema interno aún no disponible: %s".printf(uri));
                    return true;
                }

                if (uri.has_prefix("mailto:")) {
                    decision.ignore();
                    try {
                        GLib.AppInfo.launch_default_for_uri(uri, null);
                    } catch (Error e) {
                        warning("No se pudo abrir el gestor de correo: %s",
                                e.message);
                    }
                    return true;
                }

                // Popup/ventana nueva: se notifica a la ventana para que abra
                // una pestaña (como Safari); se cancela la navegación aquí.
                if (type == WebKit.PolicyDecisionType.NEW_WINDOW_ACTION) {
                    decision.ignore();
                    new_window_requested(uri);
                    return true;
                }

                return false; // navegación normal: manejo por defecto
            });
        }

        public Gtk.Widget get_widget() {
            return web_view;
        }

        public void go_back() {
            if (can_go_back)
                web_view.go_back();
        }

        public void go_forward() {
            if (can_go_forward)
                web_view.go_forward();
        }

        public void reload() {
            web_view.reload();
        }

        public void stop() {
            web_view.stop_loading();
        }

        public void load_uri(string uri) {
            _url = uri;
            web_view.load_uri(uri);
        }

        public void execute_script(string js) {
            eval_script.begin(js, (obj, res) => {
                try {
                    eval_script.end(res);
                } catch (Error e) {
                    warning("execute_script: %s", e.message);
                }
            });
        }

        // Vala 0.56 no permite invocar *_finish de un método async de vapi
        // directamente; este wrapper async recoge el resultado vía .end()
        async void eval_script(string js) throws GLib.Error {
            yield web_view.evaluate_javascript(js, -1, null, null);
        }

        public void set_user_agent(string ua) {
            web_view.get_settings().set_user_agent(ua);
        }

        public void focus() {
            web_view.grab_focus();
        }
    }

    // Fábrica única del backend compilado en esta plataforma.
    // (webview2.vala define la misma función; solo se compila uno de los dos.)
    public BrowserEngine create_engine() {
        return new WebKitGtkEngine();
    }
}
