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

            // Aceleradores estilo Safari 5.1
            set_accels_for_action("win.new-tab", {"<Control>t"});
            set_accels_for_action("win.close-tab", {"<Control>w"});
            set_accels_for_action("win.focus-address", {"<Control>l"});
            set_accels_for_action("win.reload", {"<Control>r"});
            set_accels_for_action("win.go-back", {"<Alt>Left"});
            set_accels_for_action("win.go-forward", {"<Alt>Right"});
            set_accels_for_action("win.quit", {"<Control>q"});
        }

        public static int main(string[] args) {
            var app = new App();
            return app.run(args);
        }
    }
}
