// Implementación del motor WebView2 conectada al puente C++ en Windows

namespace Baobabs {
    public class WebView2Engine : GLib.Object, BrowserEngine {
        private WebView2.Bridge? bridge;
        private bool _is_ready = false;
        public bool is_ready { get { return _is_ready; } }

        private string _url = "about:blank";
        public string url {
            get { return _url; }
            set {
                _url = value;
                if (bridge != null && _is_ready) {
                    bridge.navigate(value);
                }
            }
        }

        private string _title = "";
        public string title {
            get { return _title; }
            set { _title = value; }
        }

        private double _zoom = 1.0;
        public double zoom {
            get {
                if (bridge != null && _is_ready) {
                    return bridge.get_zoom();
                }
                return _zoom;
            }
            set {
                _zoom = value;
                if (bridge != null && _is_ready) {
                    bridge.set_zoom(value);
                }
            }
        }

        private bool _can_go_back = false;
        private bool _can_go_forward = false;
        private bool _can_reload = true;
        private bool _can_stop = false;

        public bool can_go_back { get { return _can_go_back; } }
        public bool can_go_forward { get { return _can_go_forward; } }
        public bool can_reload { get { return _can_reload; } }
        public bool can_stop { get { return _can_stop; } }

        private string? pending_uri = null;

        private Gtk.Widget? host;
        private string? profile_dir;
        private void* hwnd;

        public WebView2Engine() {
            Object();
            bridge = new WebView2.Bridge();

            bridge.set_url_changed_callback((new_url) => {
                _url = new_url;
                url_changed(new_url);
            });

            bridge.set_title_changed_callback((new_title) => {
                _title = new_title;
                title_changed(new_title);
            });

            bridge.set_nav_starting_callback((nav_url) => {
                _can_stop = true;
                notify_property("can-stop");
                load_started(nav_url);
                load_state_changed(LoadState.LOADING);
            });

            bridge.set_nav_completed_callback((is_success, error) => {
                _can_stop = false;
                notify_property("can-stop");
                bool ok = (is_success != 0);
                load_finished(ok, error);
                load_state_changed(ok ? LoadState.FINISHED : LoadState.FAILED);
            });

            bridge.set_history_changed_callback((back, fwd) => {
                bool old_back = _can_go_back;
                bool old_fwd = _can_go_forward;
                _can_go_back = (back != 0);
                _can_go_forward = (fwd != 0);
                if (old_back != _can_go_back) {
                    notify_property("can-go-back");
                }
                if (old_fwd != _can_go_forward) {
                    notify_property("can-go-forward");
                }
            });
        }

        private void initialize(void* h, int offset_y, string? p_dir) {
            if (bridge == null) return;
            bridge.initialize(h, offset_y, p_dir, () => {
                _is_ready = true;
                if (pending_uri != null) {
                    string target = pending_uri;
                    pending_uri = null;
                    bridge.navigate(target);
                } else if (_url != "about:blank") {
                    bridge.navigate(_url);
                }
            });
        }

        private void set_bounds(int x, int y, int width, int height, int win_w, int win_h) {
            if (bridge != null) {
                bridge.set_bounds(x, y, width, height, win_w, win_h);
            }
        }

        public void attach(Gtk.Widget target_host, string? p_dir = null) {
            this.host = target_host;
            this.profile_dir = p_dir;

            var toplevel = target_host.get_native() as Gtk.Window;
            if (toplevel != null) {
                this.hwnd = WebView2.get_widget_hwnd(toplevel);
            } else {
                stderr.printf("[WebView2Engine] WARNING: Host widget is not attached to a window yet.\n");
            }

            target_host.resize.connect((w, h) => {
                update_bounds();
            });
        }

        public void start() {
            if (this.host == null) {
                stderr.printf("[WebView2Engine] ERROR: start() called before attach()\n");
                return;
            }

            var toplevel = this.host.get_native() as Gtk.Window;
            if (toplevel == null) return;

            if (this.hwnd == null) {
                this.hwnd = WebView2.get_widget_hwnd(toplevel);
            }

            if (this.hwnd != null) {
                Graphene.Rect rect;
                int logical_y = 48;
                if (this.host.compute_bounds(toplevel, out rect)) {
                    logical_y = (int)rect.origin.y;
                }

                stderr.printf("[WebView2Engine] Initializing bridge with HWND=%p, logical_y=%d, profile=%s\n",
                              this.hwnd, logical_y, this.profile_dir != null ? this.profile_dir : "(null)");
                this.initialize(this.hwnd, logical_y, this.profile_dir);

                // Ajustar tamaños de forma garantizada tras la renderización inicial del layout GTK
                GLib.Timeout.add(200, () => {
                    update_bounds();
                    return false;
                });
                GLib.Timeout.add(600, () => {
                    update_bounds();
                    return false;
                });
                GLib.Timeout.add(1200, () => {
                    update_bounds();
                    return false;
                });
            } else {
                stderr.printf("[WebView2Engine] ERROR: Failed to retrieve HWND!\n");
            }
        }

        private void update_bounds() {
            if (this.host == null) return;
            var toplevel = this.host.get_native() as Gtk.Window;
            if (toplevel == null) return;

            int win_w = toplevel.get_width();
            int win_h = toplevel.get_height();

            Graphene.Rect rect;
            if (this.host.compute_bounds(toplevel, out rect)) {
                this.set_bounds((int)rect.origin.x, (int)rect.origin.y, (int)rect.size.width, (int)rect.size.height, win_w, win_h);
            }
        }

        public void go_back() {
            if (bridge != null && _is_ready) {
                bridge.go_back();
            }
        }

        public void go_forward() {
            if (bridge != null && _is_ready) {
                bridge.go_forward();
            }
        }

        public void reload() {
            if (bridge != null && _is_ready) {
                bridge.reload();
            }
        }

        public void stop() {
            if (bridge != null && _is_ready) {
                bridge.stop();
            }
        }

        public void load_uri(string uri) {
            _url = uri;
            if (bridge != null && _is_ready) {
                bridge.navigate(uri);
            } else {
                pending_uri = uri;
            }
        }

        public void execute_script(string js) {
            if (bridge != null && _is_ready) {
                bridge.execute_script(js);
            }
        }

        public void set_user_agent(string ua) {
            // Configurable vía script o CDP en revisiones posteriores
        }

        public void focus() {
            if (bridge != null && _is_ready) {
                bridge.focus();
            }
        }
    }
}