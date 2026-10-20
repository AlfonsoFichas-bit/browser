using GLib;
using Baobabs;
using Gtk;

public class TestWebKitEngine : GLib.Object {
    public static void test_create_and_attach() {
        var engine = new Baobabs.WebKitEngine();

        var window = new Gtk.Window();
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        var widget = new Gtk.DrawingArea();
        box.append(widget);
        window.set_child(box);

        string test_dir = GLib.DirUtils.make_tmp("baobabs-webkit-test-XXXXXX");
        engine.attach(widget, test_dir);

        // Assert directories were created
        assert(GLib.FileUtils.test(GLib.Path.build_filename(test_dir, "webkit"), GLib.FileTest.IS_DIR));
        assert(GLib.FileUtils.test(GLib.Path.build_filename(test_dir, "webkit", "cache"), GLib.FileTest.IS_DIR));

        // Navigation sanity checks (should not crash/assert)
        engine.start();
        engine.go_back();
        engine.go_forward();
        engine.reload();
        engine.stop();
        engine.load_uri("about:blank");

        // Check properties derived from WebView default state
        assert(engine.url != null);
        assert(engine.title != null);

        GLib.FileUtils.remove(GLib.Path.build_filename(test_dir, "webkit", "cache"));
        GLib.FileUtils.remove(GLib.Path.build_filename(test_dir, "webkit"));
        GLib.FileUtils.remove(test_dir);
    }
}

public int main (string[] args) {
    // Avoid dbus warning which causes trap
    Environment.set_variable("DBUS_SESSION_BUS_ADDRESS", "unix:path=/dev/null", true);
    Environment.set_variable("GTK_A11Y", "none", true);
    Environment.set_variable("WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS", "1", true);
    Gtk.init();
    Test.init(ref args);

    Test.add_func("/WebKitEngine/create_and_attach", TestWebKitEngine.test_create_and_attach);

    return Test.run();
}
