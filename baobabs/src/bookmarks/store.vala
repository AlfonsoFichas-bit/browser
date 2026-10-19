namespace Baobabs.Bookmarks {
    public class Store : GLib.Object {
        public Node root { get; set; }

        public signal void node_added(Node node);
        public signal void node_removed(Node node);
        public signal void node_changed(Node node);

        public Store() {
            root = new Node(NodeType.LIST);
            root.uuid = "ROOT";
            root.title = "Root";
        }
    }
}