[CCode (cheader_filename = "webview2_bridge.h")]
namespace WebView2 {

    [CCode (cname = "WebView2URLChangedCallback", has_target = true, delegate_target_pos = 1.1)]
    public delegate void URLChangedCallback (string url);

    [CCode (cname = "WebView2TitleChangedCallback", has_target = true, delegate_target_pos = 1.1)]
    public delegate void TitleChangedCallback (string title);

    [CCode (cname = "WebView2InitReadyCallback", has_target = true, delegate_target_pos = 0.1)]
    public delegate void InitReadyCallback ();

    [CCode (cname = "WebView2NavStartingCallback", has_target = true, delegate_target_pos = 1.1)]
    public delegate void NavStartingCallback (string url);

    [CCode (cname = "WebView2NavCompletedCallback", has_target = true, delegate_target_pos = 2.1)]
    public delegate void NavCompletedCallback (int is_success, string? error);

    [CCode (cname = "WebView2HistoryChangedCallback", has_target = true, delegate_target_pos = 2.1)]
    public delegate void HistoryChangedCallback (int can_go_back, int can_go_forward);

    [CCode (cname = "webview2_get_widget_hwnd")]
    public void* get_widget_hwnd (Gtk.Widget widget);

    [Compact]
    [CCode (cname = "WebView2Bridge", free_function = "webview2_bridge_free")]
    public class Bridge {
        [CCode (cname = "webview2_bridge_new")]
        public Bridge ();

        [CCode (cname = "webview2_bridge_initialize", instance_pos = 0.1)]
        public void initialize (void* hwnd, int offset_y, string? user_data_dir, [CCode (delegate_target_pos = 4.1, destroy_notify_pos = 4.2)] owned InitReadyCallback ready_cb);

        [CCode (cname = "webview2_bridge_set_url_changed_callback", instance_pos = 0.1)]
        public void set_url_changed_callback ([CCode (delegate_target_pos = 1.1, destroy_notify_pos = 1.2)] owned URLChangedCallback url_cb);

        [CCode (cname = "webview2_bridge_set_title_changed_callback", instance_pos = 0.1)]
        public void set_title_changed_callback ([CCode (delegate_target_pos = 1.1, destroy_notify_pos = 1.2)] owned TitleChangedCallback title_cb);

        [CCode (cname = "webview2_bridge_set_nav_starting_callback", instance_pos = 0.1)]
        public void set_nav_starting_callback ([CCode (delegate_target_pos = 1.1, destroy_notify_pos = 1.2)] owned NavStartingCallback nav_cb);

        [CCode (cname = "webview2_bridge_set_nav_completed_callback", instance_pos = 0.1)]
        public void set_nav_completed_callback ([CCode (delegate_target_pos = 1.1, destroy_notify_pos = 1.2)] owned NavCompletedCallback nav_cb);

        [CCode (cname = "webview2_bridge_set_history_changed_callback", instance_pos = 0.1)]
        public void set_history_changed_callback ([CCode (delegate_target_pos = 1.1, destroy_notify_pos = 1.2)] owned HistoryChangedCallback hist_cb);

        [CCode (cname = "webview2_bridge_set_callbacks", instance_pos = 0.1)]
        public void set_callbacks ([CCode (delegate_target_pos = 1.1, destroy_notify_pos = 1.2)] owned URLChangedCallback url_cb,
                                   [CCode (delegate_target_pos = 2.1, destroy_notify_pos = 2.2)] owned TitleChangedCallback title_cb);

        [CCode (cname = "webview2_bridge_navigate", instance_pos = 0.1)]
        public void navigate (string url);

        [CCode (cname = "webview2_bridge_reload", instance_pos = 0.1)]
        public void reload ();

        [CCode (cname = "webview2_bridge_stop", instance_pos = 0.1)]
        public void stop ();

        [CCode (cname = "webview2_bridge_go_back", instance_pos = 0.1)]
        public void go_back ();

        [CCode (cname = "webview2_bridge_go_forward", instance_pos = 0.1)]
        public void go_forward ();

        [CCode (cname = "webview2_bridge_can_go_back", instance_pos = 0.1)]
        public bool can_go_back ();

        [CCode (cname = "webview2_bridge_can_go_forward", instance_pos = 0.1)]
        public bool can_go_forward ();

        [CCode (cname = "webview2_bridge_execute_script", instance_pos = 0.1)]
        public void execute_script (string js);

        [CCode (cname = "webview2_bridge_set_zoom", instance_pos = 0.1)]
        public void set_zoom (double zoom);

        [CCode (cname = "webview2_bridge_get_zoom", instance_pos = 0.1)]
        public double get_zoom ();

        [CCode (cname = "webview2_bridge_focus", instance_pos = 0.1)]
        public void focus ();

        [CCode (cname = "webview2_bridge_set_bounds", instance_pos = 0.1)]
        public void set_bounds (int x, int y, int width, int height, int margin_x, int margin_y);
    }
}
