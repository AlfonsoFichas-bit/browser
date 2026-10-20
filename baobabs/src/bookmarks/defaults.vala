namespace Baobabs.Bookmarks {
    public class Defaults {
        public static Node seed() {
            var root = new Node(NodeType.LIST);
            root.uuid = GLib.Uuid.string_random();
            root.title = "Root";

            var bar = new Node(NodeType.LIST);
            bar.uuid = GLib.Uuid.string_random();
            bar.title = "BookmarksBar";

            var ddg = new Node(NodeType.LEAF);
            ddg.uuid = GLib.Uuid.string_random();
            ddg.title = "DuckDuckGo";
            ddg.url = "https://duckduckgo.com";

            var wiki = new Node(NodeType.LEAF);
            wiki.uuid = GLib.Uuid.string_random();
            wiki.title = "Wikipedia";
            wiki.url = "https://es.wikipedia.org";

            var hn = new Node(NodeType.LEAF);
            hn.uuid = GLib.Uuid.string_random();
            hn.title = "Hacker News";
            hn.url = "https://news.ycombinator.com";

            bar.children.add(ddg);
            ddg.parent = bar;
            bar.children.add(wiki);
            wiki.parent = bar;
            bar.children.add(hn);
            hn.parent = bar;

            root.children.add(bar);
            bar.parent = root;

            return root;
        }
    }
}
