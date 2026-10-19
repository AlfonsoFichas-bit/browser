using GLib;
using Baobabs;
using Baobabs.Bookmarks;

// Fixtures: plists REALES extraidos del perfil de Safari 5.1.7
// (safari/habititat-assets). El parser y el loader se validan contra ellos.
// La ruta la pasa meson como argv[1] (fallback: "fixtures").
// Se asigna en main (Vala no permite inicializador en campo global).
string fixtures_dir;

// Cuenta hojas y listas en todo el arbol
void count_nodes(Bookmarks.Node n, ref int leaves, ref int lists) {
    if (n.node_type == NodeType.LEAF)
        leaves++;
    else
        lists++;
    foreach (var c in n.children)
        count_nodes(c, ref leaves, ref lists);
}

int main(string[] args) {
    fixtures_dir = args.length > 1 ? args[1] : "fixtures";
    Test.init(ref args);

    Test.add_func("/plist/estructura-raiz", () => {
        Variant v;
        try {
            v = Plist.parse_file(Path.build_filename(fixtures_dir, "Bookmarks.plist"));
        } catch (Error e) {
            error("parse fallo: %s", e.message);
        }
        assert(v.is_of_type(new VariantType("a{sv}")));
        // claves de la raiz segun el perfil real
        assert(v.lookup_value("WebBookmarkType", VariantType.STRING).get_string()
               == "WebBookmarkTypeList");
        assert(v.lookup_value("WebBookmarkFileVersion", VariantType.INT64).get_int64() == 1);
        assert(v.lookup_value("WebBookmarkUUID", VariantType.STRING).get_string()
               == "C76B4552-E70D-2344-9350-F989AE287D02");
        // 3 hijos: BookmarksBar, BookmarksMenu, Favoritos IE importados
        assert(v.lookup_value("Children", new VariantType("av")).n_children() == 3);
    });

    Test.add_func("/plist/uridictionary", () => {
        Variant v;
        try {
            v = Plist.parse_file(Path.build_filename(fixtures_dir, "Bookmarks.plist"));
        } catch (Error e) {
            error("parse fallo: %s", e.message);
        }
        // Safari mete la URL tambien dentro de URIDictionary con clave ""
        var bar = v.lookup_value("Children", new VariantType("av")).get_child_value(0).get_variant();
        var apple = bar.lookup_value("Children", new VariantType("av")).get_child_value(0).get_variant();
        var uri = apple.lookup_value("URIDictionary", new VariantType("a{sv}"));
        assert(uri != null);
        var dup_url = uri.lookup_value("", VariantType.STRING);
        assert(dup_url != null);
        assert(dup_url.get_string() == "http://www.apple.com/es/");
        assert(uri.lookup_value("title", VariantType.STRING).get_string() == "Apple");
    });

    Test.add_func("/plist/utf16be", () => {
        // "CNN en Español" viene como UTF-16BE en el bplist
        Variant v;
        try {
            v = Plist.parse_file(Path.build_filename(fixtures_dir, "Bookmarks.plist"));
        } catch (Error e) {
            error("parse fallo: %s", e.message);
        }
        var bar = v.lookup_value("Children", new VariantType("av")).get_child_value(0).get_variant();
        var noticias = bar.lookup_value("Children", new VariantType("av")).get_child_value(5).get_variant();
        var first = noticias.lookup_value("Children", new VariantType("av")).get_child_value(0).get_variant();
        var uri = first.lookup_value("URIDictionary", new VariantType("a{sv}"));
        string title = uri.lookup_value("title", VariantType.STRING).get_string();
        assert(title == "CNN en Español");
    });

    Test.add_func("/plist/fecha-cocoa", () => {
        // TopSites.plist trae un NSDate real (marcador 0x33)
        Variant v;
        try {
            v = Plist.parse_file(Path.build_filename(fixtures_dir, "TopSites.plist"));
        } catch (Error e) {
            error("parse fallo: %s", e.message);
        }
        var ts = v.lookup_value("TopSites", new VariantType("av"));
        assert(ts.n_children() == 12);
        var banned = v.lookup_value("BannedURLStrings", new VariantType("av"));
        assert(banned.n_children() == 0);
        var mod = v.lookup_value("DisplayedSitesLastModified", VariantType.DOUBLE);
        assert(mod != null);
        // 2026-10-18 ~ 814055715 en epoch Cocoa
        double cocoa = mod.get_double();
        assert(cocoa > 814000000 && cocoa < 815000000);
        // conversion a unix con el offset conocido
        int64 unix_s = EpochUtils.cocoa_to_unix(cocoa);
        assert(unix_s > 1792000000 && unix_s < 1793000000);
    });

    Test.add_func("/bookmarks/arbol-real", () => {
        Bookmarks.Node root;
        try {
            root = Loader.from_file(Path.build_filename(fixtures_dir, "Bookmarks.plist"));
        } catch (Error e) {
            error("loader fallo: %s", e.message);
        }
        assert(root.node_type == NodeType.LIST);
        assert(root.parent == null);
        assert(root.title == null); // la raiz no tiene Title en el perfil real
        assert(root.uuid == "C76B4552-E70D-2344-9350-F989AE287D02");

        // 3 hijos: BookmarksBar, BookmarksMenu, Favoritos IE importados
        assert(root.children.size == 3);
        assert(root.children[0].title == "BookmarksBar");
        assert(root.children[1].title == "BookmarksMenu");
        assert(root.children[2].title == "Favoritos IE importados");

        // BookmarksMenu viene VACIO (sin clave Children en el plist)
        assert(root.children[1].children.size == 0);

        // la barra tiene 7 hijos: 5 hojas sueltas + Noticias + Populares
        var bar = root.children[0];
        assert(bar.children.size == 7);
        assert(bar.children[0].title == "Apple");
        assert(bar.children[0].url == "http://www.apple.com/es/");
        assert(bar.children[0].node_type == NodeType.LEAF);
        assert(bar.children[0].uuid == "0C638567-D260-40B5-B1E6-ACD1D82FCAFA");
        // el padre enlaza hacia atras
        assert(bar.children[0].parent == bar);

        // carpetas anidadas
        assert(bar.children[5].title == "Noticias");
        assert(bar.children[5].node_type == NodeType.LIST);
        assert(bar.children[5].children.size == 7);
        assert(bar.children[6].title == "Populares");
        assert(bar.children[6].children.size == 9);

        // recuento total del perfil real:
        //   hojas: 5 bar + 7 Noticias + 9 Populares + 1 Bing = 22
        //   listas: raiz + bar + Noticias + Populares + Menu + IE + Links = 7
        int leaves = 0, lists = 0;
        count_nodes(root, ref leaves, ref lists);
        assert(leaves == 22);
        assert(lists == 7);
    });

    Test.add_func("/bookmarks/errores", () => {
        // raiz que no es dict -> BookmarkError
        try {
            Loader.from_variant(new Variant.string("no-soy-dict"));
            assert_not_reached();
        } catch (BookmarkError e) {
            assert(e is BookmarkError.INVALID_SCHEMA);
        } catch (Error e) {
            assert_not_reached();
        }
        // tipo de bookmark desconocido
        var b = new VariantBuilder(new VariantType("a{sv}"));
        b.add("{sv}", "WebBookmarkType", new Variant.string("WebBookmarkTypeChatarra"));
        b.add("{sv}", "WebBookmarkUUID", new Variant.string("X"));
        try {
            Loader.from_variant(b.end());
            assert_not_reached();
        } catch (BookmarkError e) {
            assert(e is BookmarkError.INVALID_SCHEMA);
        } catch (Error e) {
            assert_not_reached();
        }
        // bplist corrupto
        try {
            uint8[] junk = { 'b', 'p', 'l', 'i', 's', 't', '0', '0', 0, 1, 2, 3 };
            Plist.parse_bytes(junk);
            assert_not_reached();
        } catch (PlistError e) {
            assert(e is PlistError.INVALID_FORMAT);
        } catch (Error e) {
            assert_not_reached();
        }
    });

    return Test.run();
}
