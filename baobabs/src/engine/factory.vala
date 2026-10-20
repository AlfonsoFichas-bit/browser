namespace Baobabs {
    public BrowserEngine create_engine() {
#if WINDOWS
        return new WebView2Engine();
#else
        return new WebKitEngine();
#endif
    }
}
