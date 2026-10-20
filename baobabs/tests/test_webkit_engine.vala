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

        // Run the loop to process dbus messages or internal states that flush settings
        var loop = new GLib.MainLoop();
        GLib.Timeout.add(50, () => {
            loop.quit();
            return false;
        });
        loop.run();

        // Assert cookies file was created since the profile dir is persistent
        assert(GLib.FileUtils.test(GLib.Path.build_filename(test_dir, "webkit", "cookies.sqlite"), GLib.FileTest.EXISTS));

        GLib.FileUtils.remove(GLib.Path.build_filename(test_dir, "webkit", "cache"));
        GLib.FileUtils.remove(GLib.Path.build_filename(test_dir, "webkit", "cookies.sqlite"));
        GLib.FileUtils.remove(GLib.Path.build_filename(test_dir, "webkit"));
        GLib.FileUtils.remove(test_dir);
    }

    public static void test_navigation_success() {
        var engine = new Baobabs.WebKitEngine();
        var window = new Gtk.Window();
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        var widget = new Gtk.DrawingArea();
        box.append(widget);
        window.set_child(box);
        engine.attach(widget, null);

        var loop = new GLib.MainLoop();
        bool is_finished = false;
        bool was_success = false;

        engine.load_finished.connect((success, error) => {
            is_finished = true;
            was_success = success;
            loop.quit();
        });

        engine.load_uri("about:blank");

        GLib.Timeout.add_seconds(3, () => {
            loop.quit();
            return false;
        });

        loop.run();

        assert(is_finished);
        assert(was_success);
    }

    public static void test_navigation_closed_port() {
        var engine = new Baobabs.WebKitEngine();
        var window = new Gtk.Window();
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        var widget = new Gtk.DrawingArea();
        box.append(widget);
        window.set_child(box);
        engine.attach(widget, null);

        var loop = new GLib.MainLoop();
        bool is_finished = false;
        bool was_success = true;

        engine.load_finished.connect((success, error) => {
            is_finished = true;
            was_success = success;
            loop.quit();
        });

        // Case A - closed port
        engine.load_uri("http://127.0.0.1:1/x");

        GLib.Timeout.add_seconds(3, () => {
            loop.quit();
            return false;
        });

        loop.run();

        assert(is_finished);
        assert(!was_success);
    }

    public static void test_navigation_invalid_dns() {
        var engine = new Baobabs.WebKitEngine();
        var window = new Gtk.Window();
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        var widget = new Gtk.DrawingArea();
        box.append(widget);
        window.set_child(box);
        engine.attach(widget, null);

        var loop = new GLib.MainLoop();
        bool is_finished = false;
        bool was_success = true;
        int finish_calls = 0;

        engine.load_finished.connect((success, error) => {
            is_finished = true;
            was_success = success;
            finish_calls++;

            // Wait for 2nd cycle of WebKit (error page)
            if (finish_calls >= 2) {
                loop.quit();
            }
        });

        // Case B - invalid DNS
        engine.load_uri("http://non-existent.invalid");

        GLib.Timeout.add_seconds(3, () => {
            loop.quit();
            return false;
        });

        loop.run();

        assert(is_finished);
        assert(!was_success);
    }
}

public int main (string[] args) {
    // Avoid dbus warning which causes trap
    Environment.set_variable("DBUS_SESSION_BUS_ADDRESS", "unix:path=/dev/null", true);
    Environment.set_variable("GTK_A11Y", "none", true);
    Environment.set_variable("WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS", "1", true);

    if (!Gtk.init_check()) {
        return 77;
    }
    Test.init(ref args);

    Test.add_func("/WebKitEngine/create_and_attach", TestWebKitEngine.test_create_and_attach);
    Test.add_func("/WebKitEngine/navigation_success", TestWebKitEngine.test_navigation_success);
    Test.add_func("/WebKitEngine/navigation_closed_port", TestWebKitEngine.test_navigation_closed_port);
    Test.add_func("/WebKitEngine/navigation_invalid_dns", TestWebKitEngine.test_navigation_invalid_dns);

    return Test.run();
}
