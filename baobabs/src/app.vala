using Gtk;

namespace Baobabs {
    public class App : Gtk.Application {
        public App() {
            Object(application_id: "org.baobabs.browser",
                   flags: ApplicationFlags.FLAGS_NONE);
        }

        protected override void activate() {
            var win = new MainWindow(this);
            win.present();
        }

        public static int main(string[] args) {
            var app = new App();
            return app.run(args);
        }
    }
}