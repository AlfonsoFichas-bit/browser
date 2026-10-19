[CCode (cheader_filename = "webview2_bridge.h")]
namespace WebView2 {

    [CCode (cname = "WebView2URLChangedCallback", has_target = true, delegate_target_pos = 1.1)]
    public delegate void URLChangedCallback (string url);

    [CCode (cname = "WebView2TitleChangedCallback", has_target = true, delegate_target_pos = 1.1)]
    public delegate void TitleChangedCallback (string title);

    [CCode (cname = "WebView2InitReadyCallback", has_target = true, delegate_target_pos = 0.1)]
    public delegate void InitReadyCallback ();

    [Compact]
    [CCode (cname = "WebView2Bridge", free_function = "webview2_bridge_free")]
    public class Bridge {
        [CCode (cname = "webview2_bridge_new")]
        public Bridge ();

        [CCode (cname = "webview2_bridge_initialize", instance_pos = 0.1)]
        public void initialize (void* hwnd, int offset_y, InitReadyCallback ready_cb);

        [CCode (cname = "webview2_bridge_set_callbacks", instance_pos = 0.1)]
        public void set_callbacks (URLChangedCallback url_cb, TitleChangedCallback title_cb);

        [CCode (cname = "webview2_bridge_navigate", instance_pos = 0.1)]
        public void navigate (string url);

        [CCode (cname = "webview2_bridge_reload", instance_pos = 0.1)]
        public void reload ();

        [CCode (cname = "webview2_bridge_go_back", instance_pos = 0.1)]
        public void go_back ();

        [CCode (cname = "webview2_bridge_go_forward", instance_pos = 0.1)]
        public void go_forward ();

        [CCode (cname = "webview2_bridge_resize", instance_pos = 0.1)]
        public void resize (int width, int height);
    }
}
