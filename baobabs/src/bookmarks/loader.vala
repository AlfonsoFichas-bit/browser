namespace Baobabs.Bookmarks {
    public errordomain BookmarkError {
        INVALID_SCHEMA
    }

    // Reconstruye el arbol de nodos WebBookmark* desde un plist parseado.
    // Fiel al esquema real (HABITAT.md 1.2):
    //   List  -> Children (opcional si vacia) + Title
    //   Leaf  -> URLString + URIDictionary.title
    //   ambos -> WebBookmarkType + WebBookmarkUUID (se normaliza a mayusculas)
    public class Loader : GLib.Object {
        public static Node from_variant(Variant root) throws BookmarkError {
            if (!root.is_of_type(new VariantType("a{sv}")))
                throw new BookmarkError.INVALID_SCHEMA("la raiz no es un dict");
            return node_from_variant(root, null);
        }

        public static Node from_file(string path) throws PlistError, BookmarkError, GLib.FileError {
            return from_variant(Plist.parse_file(path));
        }

        static Node node_from_variant(Variant dict, Node? parent) throws BookmarkError {
            string type_str = lookup_string(dict, "WebBookmarkType");
            NodeType ntype;
            switch (type_str) {
            case "WebBookmarkTypeLeaf":
                ntype = NodeType.LEAF;
                break;
            case "WebBookmarkTypeList":
                ntype = NodeType.LIST;
                break;
            case "WebBookmarkTypeProxy":
                ntype = NodeType.PROXY;
                break;
            default:
                throw new BookmarkError.INVALID_SCHEMA("WebBookmarkType desconocido: %s", type_str);
            }

            var node = new Node(ntype);
            node.parent = parent;
            // Safari guarda los UUID en mayusculas; se normaliza por consistencia
            node.uuid = lookup_string(dict, "WebBookmarkUUID").up();

            if (ntype == NodeType.LEAF) {
                node.url = lookup_string(dict, "URLString");
                // El titulo de una hoja vive en URIDictionary.title
                var uri = dict.lookup_value("URIDictionary", new VariantType("a{sv}"));
                if (uri != null) {
                    var title = uri.lookup_value("title", VariantType.STRING);
                    if (title != null)
                        node.title = title.get_string();
                }
            } else {
                // En las carpetas el titulo va en Title (mayuscula); BookmarksBar
                // y BookmarksMenu lo llevan, la raiz no
                var title = dict.lookup_value("Title", VariantType.STRING);
                if (title != null)
                    node.title = title.get_string();

                // Carpetas vacias (BookmarksMenu, Links) omiten Children
                var children = dict.lookup_value("Children", new VariantType("av"));
                if (children != null) {
                    size_t n = children.n_children();
                    for (uint i = 0; i < n; i++) {
                        // "av": los hijos vienen envueltos como variant ("v")
                        Variant child = children.get_child_value(i).get_variant();
                        if (!child.is_of_type(new VariantType("a{sv}")))
                            throw new BookmarkError.INVALID_SCHEMA("hijo no es un dict");
                        node.children.add(node_from_variant(child, node));
                    }
                }
            }
            return node;
        }

        static string lookup_string(Variant dict, string key) throws BookmarkError {
            var v = dict.lookup_value(key, VariantType.STRING);
            if (v == null)
                throw new BookmarkError.INVALID_SCHEMA("falta la clave %s", key);
            return v.get_string();
        }
    }
}
