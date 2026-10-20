using Gtk;

namespace Baobabs {
    public class WebKitEngine : GLib.Object, BrowserEngine {
        private WebKit.WebView web_view;
        private string pending_url = "about:blank";

        // Properties implementation
        public string url { get; set; default = ""; }
        public string title { get; set; default = "about:blank"; }
        public double zoom { get; set; default = 1.0; }
        public bool can_go_back { get { return true; } }
        public bool can_go_forward { get { return true; } }
        public bool can_reload { get { return true; } }
        public bool can_stop { get { return false; } }

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
            // Group 2: Create WebKitWebView and insert into the host
            var settings = new WebKit.Settings();
            web_view = new WebKit.WebView();
            web_view.set_settings(settings);
            web_view.hexpand = true;
            web_view.vexpand = true;

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
    }
}
