namespace Baobabs {
    public enum LoadState {
        IDLE,
        LOADING,
        FINISHED,
        FAILED
    }

    // Contrato del motor web intercambiable (HABITAT.md: fase 1 Linux,
    // fase 4 Windows/WebView2). Las señales usan el mismo vocabulario que
    // las notificaciones de Safari para facilitar seguir la documentación.
    public interface BrowserEngine : GLib.Object {
        public abstract string url { get; set; }
        public abstract string title { get; set; }
        public abstract double zoom { get; set; }
        public abstract bool can_go_back { get; }
        public abstract bool can_go_forward { get; }
        public abstract bool can_reload { get; }
        public abstract bool can_stop { get; }

        public signal void load_started(string url);
        public signal void load_finished(bool success, string? error);
        public signal void title_changed(string title);
        public signal void url_changed(string url);
        public signal void progress_changed(double progress);
        public signal void load_state_changed(LoadState state);
        // Popup/ventana nueva (NEW_WINDOW_ACTION): la ventana decide abrir
        // una pestaña nueva; el motor no crea pestañas por sí mismo.
        public signal void new_window_requested(string url);

        public abstract void go_back();
        public abstract void go_forward();
        public abstract void reload();
        public abstract void stop();
        public abstract void load_uri(string uri);
        public abstract void execute_script(string js);
        public abstract void set_user_agent(string ua);
        public abstract void focus();

        // Widget que muestra la página (transporte según plataforma:
        // WebKitWebView en Linux, HWND adaptado en Windows — fase 4).
        public abstract Gtk.Widget get_widget();
    }
}
