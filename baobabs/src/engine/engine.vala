using Gtk;

namespace Baobabs {
    public enum LoadState {
        IDLE,
        LOADING,
        FINISHED,
        FAILED
    }

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

        public abstract void go_back();
        public abstract void go_forward();
        public abstract void reload();
        public abstract void stop();
        public abstract void load_uri(string uri);
        public abstract void execute_script(string js);
        public abstract void set_user_agent(string ua);
        public abstract void focus();

        public abstract void attach(Gtk.Widget host, string? profile_dir = null);
        public abstract void start();
    }
}