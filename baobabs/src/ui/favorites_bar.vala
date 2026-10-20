using Gtk;

namespace Baobabs {
    public class FavoritesBar : Gtk.Box {
        public signal void open_url(string url);

        private Bookmarks.Store store;

        public FavoritesBar(Bookmarks.Store store) {
            Object(orientation: Orientation.HORIZONTAL, spacing: 4);
            this.store = store;
            this.vexpand = false;

            build_ui();
        }

        private void build_ui() {
            var root = store.root;
            Bookmarks.Node? bar_node = null;

            if (root != null) {
                foreach (var child in root.children) {
                    if (child.node_type == Bookmarks.NodeType.LIST && child.title == "BookmarksBar") {
                        bar_node = child;
                        break;
                    }
                }
            }

            if (bar_node == null) {
                bar_node = root;
            }

            if (bar_node != null) {
                build_level(this, bar_node);
            }
        }

        private void build_level(Gtk.Box container, Bookmarks.Node folder_node) {
            foreach (var node in folder_node.children) {
                if (node.node_type == Bookmarks.NodeType.LEAF) {
                    var btn = new Button.with_label(display_title_for(node));
                    // use unowned or a local variable to prevent capturing `node` variable reference inside closure loop
                    string url_to_open = node.url ?? "";
                    btn.clicked.connect(() => {
                        if (url_to_open.length > 0) {
                            open_url(url_to_open);
                        }
                    });
                    container.append(btn);
                } else if (node.node_type == Bookmarks.NodeType.LIST || node.node_type == Bookmarks.NodeType.PROXY) {
                    var menu_btn = new MenuButton();
                    menu_btn.label = display_title_for(node);

                    var popover = new Popover();
                    var vbox = new Box(Orientation.VERTICAL, 2);
                    popover.set_child(vbox);
                    menu_btn.popover = popover;

                    build_level(vbox, node);

                    container.append(menu_btn);
                }
            }
        }

        private string display_title_for(Bookmarks.Node node) {
            if (node.title != null && node.title.length > 0)
                return node.title;
            if (node.url != null) {
                try {
                    var host = GLib.Uri.parse(node.url, GLib.UriFlags.NONE).get_host();
                    if (host != null && host.length > 0)
                        return host;
                } catch (GLib.UriError e) {
                    // fallback abajo
                }
            }
            return node.url ?? "(sin título)";
        }
    }
}
