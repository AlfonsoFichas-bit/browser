using Gtk;

namespace Baobabs {
    public class WebKitEngine : GLib.Object, BrowserEngine {
        private WebKit.WebView web_view;
        private string pending_url = "about:blank";

        // Properties implementation
        public string url {
            get { return web_view != null && web_view.uri != null ? web_view.uri : ""; }
            set {}
        }

        public string title {
            get { return web_view != null && web_view.title != null ? web_view.title : "about:blank"; }
            set {}
        }

        public double zoom { get; set; default = 1.0; }

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
            if (web_view != null) {
                web_view.load_uri(uri);
            }
        }

        public void execute_script(string js) {
            // Group 5
        }

        public void set_user_agent(string ua) {
            // Group 5
        }

        public void focus() {
            if (web_view != null) {
                web_view.grab_focus();
            }
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
            } else {
                session = new WebKit.NetworkSession.ephemeral();
            }

            // Group 2: Create WebKitWebView and insert into the host
            var settings = new WebKit.Settings();
            web_view = (WebKit.WebView)GLib.Object.new(typeof(WebKit.WebView),
                "network-session", session,
                "settings", settings
            );

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
                        load_finished(true, null);
                        load_state_changed(LoadState.FINISHED);
                        break;
                    default:
                        break;
                }
                update_navigation_actions();
            });

            web_view.load_failed.connect((event, failing_uri, error) => {
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

            // Option A with fallback to Option B
            var parent = host.get_parent();
            if (parent != null && parent is Gtk.Box) {
                var box = (Gtk.Box)parent;
                box.remove(host);
                box.append(web_view);
            } else if (host is Gtk.Box) {
                var box = (Gtk.Box)host;
                box.append(web_view);
            } else if (parent != null && parent is Gtk.Widget) {
                // Not sure if parent implements something like container or other api,
                // fall back logic safely. If nothing works, just hold reference to web_view.
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
