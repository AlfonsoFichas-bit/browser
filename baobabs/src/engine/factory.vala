namespace Baobabs {
    public BrowserEngine create_engine() {
#if WINDOWS
        return new WebView2Engine();
#else
        // Linux: WebKitEngine se añadirá cuando exista
        assert_not_reached();
#endif
    }
}
