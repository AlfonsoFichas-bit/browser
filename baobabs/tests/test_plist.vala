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

    Test.add_func("/plist/writer-roundtrip", () => {
        // parse → write → parse debe ser estable en TODOS los plists binarios
        // (los XML — Defaults/UserAgents — aún no los escribe el writer)
        string[] files = {
            "Bookmarks.plist", "History.plist", "TopSites.plist",
            "ReadingList.plist"
        };
        foreach (var f in files) {
            Variant v;
            try {
                v = Plist.parse_file(Path.build_filename(fixtures_dir, f));
            } catch (Error e) {
                error("%s: parse fallo: %s", f, e.message);
            }
            uint8[] bytes;
            try {
                bytes = PlistWriter.to_bytes(v);
            } catch (Error e) {
                error("%s: escritura fallo: %s", f, e.message);
            }
            // TEMP DEBUG
            try { FileUtils.set_data("/tmp/rt-" + f, bytes); } catch (Error e) {}
            Variant w;
            try {
                w = Plist.parse_bytes(bytes);
            } catch (Error e) {
                error("%s: reparse fallo: %s", f, e.message);
            }
            // comparación profunda vía representación GVariant
            assert(v.print(true) == w.print(true));
        }
    });

    Test.add_func("/plist/writer-tipos", () => {
        // Casos de borde del escritor: UTF-16 (no ASCII), strings largos
        // (>=15, conteo extendido), ints de todos los tamaños, bools,
        // data, arrays y dicts anidados.
        var root = new VariantBuilder(new VariantType("a{sv}"));
        root.add("{sv}", "ascii", new Variant.string("hola"));
        root.add("{sv}", "unicode", new Variant.string("Ñandú 日本 🦩"));
        root.add("{sv}", "largo", new Variant.string(string.nfill(40, 'x')));
        root.add("{sv}", "int0", new Variant.int64(0));
        root.add("{sv}", "int8", new Variant.int64(200));       // 2 B
        root.add("{sv}", "int-neg", new Variant.int64(-12345)); // 2 B
        root.add("{sv}", "int32", new Variant.int64(70000));    // 4 B
        root.add("{sv}", "int64", new Variant.int64(1 << 40));
        root.add("{sv}", "real", new Variant.double(3.14159));
        root.add("{sv}", "si", new Variant.boolean(true));
        root.add("{sv}", "no", new Variant.boolean(false));
        root.add("{sv}", "null",
                 new Variant.maybe(new VariantType("v"), null)); // -> 0x00
        var arr = new VariantBuilder(new VariantType("av"));
        for (int i = 0; i < 40; i++) // array largo -> count extendido
            arr.add_value(new Variant.int64(i));
        root.add("{sv}", "array", arr.end());
        uint8[] payload = { 0xDE, 0xAD, 0xBE, 0xEF };
        root.add("{sv}", "bytes",
                 new Variant.from_bytes(new VariantType("ay"),
                                        new Bytes.take(payload), true));
        var src = root.end();

        uint8[] bytes;
        try {
            bytes = PlistWriter.to_bytes(src);
        } catch (Error e) {
            error("escritura fallo: %s", e.message);
        }
        Variant back;
        try {
            back = Plist.parse_bytes(bytes);
        } catch (Error e) {
            error("reparse fallo: %s", e.message);
        }
        assert(src.print(true) == back.print(true));

        // el parser de Safari debe dar igual: comprobación cruzada de claves
        assert(back.lookup_value("unicode", VariantType.STRING)
                   .get_string() == "Ñandú 日本 🦩");
        assert(back.lookup_value("array", new VariantType("av"))
                   .n_children() == 40);
        assert(back.lookup_value("int-neg", VariantType.INT64)
                   .get_int64() == -12345);
    });

    Test.add_func("/history/save-load", () => {
        var s = new Baobabs.History.Store();
        s.record_visit("https://example.com/", "Ejemplo");
        s.record_visit("https://example.com/", "Ejemplo");
        s.record_visit("https://otro.example/página", "Otro");

        string path;
        try {
            // fd queda abierto a propósito: solo lo usa este test efímero
            FileUtils.open_tmp("baobabs-hist-XXXXXX", out path);
        } catch (Error e) {
            error("tmp fallo: %s", e.message);
        }
        try {
            s.save_to_file(path);
        } catch (Error e) {
            error("save fallo: %s", e.message);
        }

        var s2 = new Baobabs.History.Store();
        s2.load_from_file(path);
        assert(s2.entries.size == 2);
        var e1 = s2.entries.get("https://example.com/");
        assert(e1 != null);
        assert(e1.visit_count == 2);
        assert(e1.title == "Ejemplo");
        assert(e1.last_visited_unix > 1792000000); // > 2026-10
        // epoch Cocoa coherente: unix - offset
        assert(e1.last_visited_cocoa ==
               (double)(e1.last_visited_unix - COCOA_EPOCH_OFFSET));
        var e2 = s2.entries.get("https://otro.example/página");
        assert(e2 != null);
        assert(e2.visit_count == 1);
        assert(e2.title == "Otro");
        FileUtils.remove(path);

        // fichero ausente = historial vacío, sin lanzar
        var s3 = new Baobabs.History.Store();
        s3.load_from_file("/no/existe/baobabs/History.plist");
        assert(s3.entries.size == 0);
    });

    return Test.run();
}
