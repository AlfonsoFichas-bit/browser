using Gtk;

namespace Baobabs {
    public class WebKitEngine : GLib.Object, BrowserEngine {
        private WebKit.WebView web_view;
        private string pending_url = "about:blank";
        private string requested_uri = "about:blank";
        private bool load_failed_flag = false;
        private string pending_user_agent = "";
        private double pending_zoom = 1.0;

        // Properties implementation
        public string url {
            get { return web_view != null && web_view.uri != null ? web_view.uri : ""; }
            set {}
        }

        public string title {
            get { return web_view != null && web_view.title != null ? web_view.title : "about:blank"; }
            set {}
        }

        public double zoom {
            get {
                return web_view != null ? web_view.zoom_level : pending_zoom;
            }
            set {
                pending_zoom = value;
                if (web_view != null) {
                    web_view.zoom_level = value;
                }
            }
        }

        public bool can_go_back {
            get { return web_view != null ? web_view.can_go_back() : false; }
        }

        public bool can_go_forward {
            get { return web_view != null ? web_view.can_go_forward() : false; }
        }

        public bool can_reload {
            get { return web_view != null; }
        }

        public bool can_stop {
            get { return web_view != null && web_view.is_loading; }
        }

        public WebKitEngine() {
        }

        public void go_back() {
            if (web_view != null) {
                web_view.go_back();
            }
        }

        public void go_forward() {
            if (web_view != null) {
                web_view.go_forward();
            }
        }

        public void reload() {
            if (web_view != null) {
                web_view.reload();
            }
        }

        public void stop() {
            if (web_view != null) {
                web_view.stop_loading();
            }
        }

        public void load_uri(string uri) {
            pending_url = uri;
            requested_uri = uri;
            load_failed_flag = false;

            if (web_view != null) {
                web_view.load_uri(uri);
            }
        }

        public void execute_script(string js) {
            if (web_view == null) {
                return;
            }
            web_view.evaluate_javascript.begin(js, -1, null, null, null, (obj, res) => {
                try {
                    web_view.evaluate_javascript.end(res);
                } catch (GLib.Error e) {
                    // No hay canal de error en el contrato; ignora o loguea.
                    GLib.warning("execute_script: %s", e.message);
                }
            });
        }

        public void set_user_agent(string ua) {
            pending_user_agent = ua;
            if (web_view != null) {
                // Settings.user_agent es una propiedad 'construct-only'
                // Un cambio posterior requiere la recarga del web_view tras reconstruir Settings.
                // Esta limitación documentada provoca que el cambio solo será efectivo en
                // nuevas construcciones o attach()
                GLib.warning("set_user_agent was called after web_view initialization. Change will not apply to current view.");
            }
        }

        public void focus() {
            if (web_view != null) {
                web_view.grab_focus();
            }
        }

        public void unfocus() {
            // No-op for WebKitGTK. Focus management is handled properly by GTK natively.
        }

        public void attach(Gtk.Widget host, string? profile_dir = null) {
            // Group 3: Perfil persistente
            WebKit.NetworkSession session = null;
            if (profile_dir != null && profile_dir.length > 0) {
                string data_dir = GLib.Path.build_filename(profile_dir, "webkit");
                string cache_dir = GLib.Path.build_filename(profile_dir, "webkit", "cache");

                // Create directories if they do not exist
                GLib.DirUtils.create_with_parents(data_dir, 0700);
                GLib.DirUtils.create_with_parents(cache_dir, 0700);

                session = new WebKit.NetworkSession(data_dir, cache_dir);

                // Persistir cookies en disco (sin esto se pierden al cerrar)
                string cookie_file = GLib.Path.build_filename(data_dir, "cookies.sqlite");
                session.get_cookie_manager().set_persistent_storage(
                    cookie_file, WebKit.CookiePersistentStorage.SQLITE);
            } else {
                session = new WebKit.NetworkSession.ephemeral();
            }

            // Group 2: Create WebKitWebView and insert into the host
            WebKit.Settings settings;
            if (pending_user_agent != "") {
                settings = (WebKit.Settings)GLib.Object.new(typeof(WebKit.Settings),
                    "user-agent", pending_user_agent);
            } else {
                settings = new WebKit.Settings();
            }

            web_view = (WebKit.WebView)GLib.Object.new(typeof(WebKit.WebView),
                "network-session", session,
                "settings", settings
            );

            // Set pending configurations
            web_view.zoom_level = pending_zoom;
            web_view.hexpand = true;
            web_view.vexpand = true;

            // Connect to navigation and state signals
            web_view.load_changed.connect((event) => {
                switch (event) {
                    case WebKit.LoadEvent.STARTED:
                        load_started(web_view.uri);
                        load_state_changed(LoadState.LOADING);
                        break;
                    case WebKit.LoadEvent.FINISHED:
                        bool success = true;
                        string error_msg = null;

                        if (load_failed_flag) {
                            success = false;
                        } else if (web_view.uri != null && web_view.uri != requested_uri) {
                            success = false;
                            error_msg = "Connection Refused or URL mismatch";
                            load_failed_flag = true;
                        }

                        if (success) {
                            load_finished(true, null);
                            load_state_changed(LoadState.FINISHED);
                        } else {
                            if (error_msg == null) {
                                error_msg = "Unknown error or DNS issue";
                            }
                            load_finished(false, error_msg);
                            load_state_changed(LoadState.FAILED);
                        }
                        break;
                    default:
                        break;
                }
                update_navigation_actions();
            });

            web_view.load_failed.connect((event, failing_uri, error) => {
                load_failed_flag = true;
                load_finished(false, error.message);
                load_state_changed(LoadState.FAILED);
                update_navigation_actions();
                return false;
            });

            web_view.notify["uri"].connect(() => {
                url_changed(web_view.uri);
                notify_property("url");
            });

            web_view.notify["title"].connect(() => {
                title_changed(web_view.title != null ? web_view.title : "about:blank");
                notify_property("title");
            });

            web_view.notify["estimated-load-progress"].connect(() => {
                progress_changed(web_view.estimated_load_progress);
            });

            web_view.notify["is-loading"].connect(() => {
                update_navigation_actions();
            });

            if (host is Gtk.Overlay) {
                ((Gtk.Overlay)host).add_overlay(web_view);
            } else if (host is Gtk.Box) {
                ((Gtk.Box)host).append(web_view);
            } else {
                GLib.warning("WebKitEngine.attach: host no es contenedor (Overlay/Box); el web_view no se montará.");
            }
        }

        public void start() {
            if (web_view != null) {
                web_view.load_uri(pending_url);
            }
        }

        private void update_navigation_actions() {
            notify_property("can-go-back");
            notify_property("can-go-forward");
            notify_property("can-stop");
            notify_property("can-reload");
        }
    }
}
