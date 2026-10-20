using Gtk;

namespace Baobabs {
    public class App : Gtk.Application {
        private string? initial_url = null;

        public App(string? url = null) {
            Object(application_id: "org.baobabs.browser",
                   flags: ApplicationFlags.FLAGS_NONE);
            this.initial_url = url;
        }

        protected override void activate() {
            var display = Gdk.Display.get_default();
            if (display != null) {
                var provider = new Gtk.CssProvider();
                provider.load_from_resource("/org/baobabs/browser/style.css");
                Gtk.StyleContext.add_provider_for_display(
                    display,
                    provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                );
            }

            var win = new MainWindow(this, initial_url);
            win.present();
            win.start();
        }

        public static int main(string[] args) {
            string? url = (args.length > 1) ? args[1] : null;
            var app = new App(url);
            return app.run(new string[]{ args[0] });
        }
    }
}