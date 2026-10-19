// Stub para WebView2 backend (Windows, fase 4)
// Se implementará con el shim C++ (WebView2.h + carga dinámica de
// WebView2Loader.dll) exponiendo una API C plana → VAPI.
// NOTA: la UI de Windows (Win32 nativo vs GTK4) se decide en la fase 4;
// gtk4 no puede embeber HWNDs, así que get_widget() aquí es provisional.

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

        private Gtk.Label placeholder;

        public WebView2Engine() {
            Object();
        }

        construct {
            placeholder = new Gtk.Label(
                "Backend WebView2 (fase 4) — no disponible en esta plataforma");
            placeholder.margin_top = 24;
            placeholder.margin_bottom = 24;
        }

        public Gtk.Widget get_widget() {
            return placeholder;
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

    // Fábrica del backend (solo se compila este fichero si NO hay WebKitGTK)
    public BrowserEngine create_engine() {
        return new WebView2Engine();
    }
}
