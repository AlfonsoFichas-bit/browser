using Gtk;

namespace Baobabs {
    public class MainWindow : ApplicationWindow {
        public MainWindow(Gtk.Application app) {
            Object(application: app,
                   title: "Baobabs",
                   default_width: 1024,
                   default_height: 768);
        }

        construct {
            var header = new HeaderBar();
            header.show_title_buttons = true;
            set_titlebar(header);

            var label = new Label("Baobabs — Safari 5.1.7 inspired browser");
            label.margin_top = 24;
            label.margin_bottom = 24;
            label.margin_start = 24;
            label.margin_end = 24;

            var box = new Box(Orientation.VERTICAL, 0);
            box.append(label);
            set_child(box);
        }
    }
}