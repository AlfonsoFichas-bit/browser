// Stub para WebView2 backend (Windows-first)
// Se implementará cuando tengamos el entorno WebView2 + VAPI adecuado

namespace Baobabs {
    public class WebView2Engine : GLib.Object, BrowserEngine {
        public string url { get; set; default = "about:blank"; }
        public string title { get; set; default = ""; }
        public double zoom { get; set; default = 1.0; }

        private bool _can_go_back = false;
        private bool _can_go_forward = false;
        private bool _can_reload = false;
        private bool _can_stop = false;

        public bool can_go_back { get { return _can_go_back; } }
        public bool can_go_forward { get { return _can_go_forward; } }
        public bool can_reload { get { return _can_reload; } }
        public bool can_stop { get { return _can_stop; } }

        public WebView2Engine() {
            Object();
        }

        public void go_back() {}
        public void go_forward() {}
        public void reload() {}
        public void stop() {}
        public void load_uri(string uri) { this.url = uri; }
        public void execute_script(string js) {}
        public void set_user_agent(string ua) {}
        public void focus() {}
    }
}