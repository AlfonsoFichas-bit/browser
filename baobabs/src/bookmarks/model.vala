using GLib;

namespace Baobabs.Bookmarks {
    public enum NodeType {
        LIST,
        LEAF,
        PROXY
    }

    public class Node : Object {
        public string uuid { get; set; }
        public string? title { get; set; }
        public NodeType node_type { get; set; }
        public string? url { get; set; }
        public Node? parent { get; set; }
        public Gee.ArrayList<Node> children { get; construct set; }

        construct {
            children = new Gee.ArrayList<Node>();
        }

        public Node(NodeType t) {
            Object(node_type: t);
        }
    }
}