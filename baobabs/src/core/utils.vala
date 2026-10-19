namespace Baobabs {
    public class Utils : GLib.Object {
        public static string generate_uuid() {
            var uuid = GLib.Uuid.string_random();
            return uuid.up();
        }

        // Normaliza lo que se teclea en la barra de dirección, al estilo
        // Safari: URL si lo parece, búsqueda si no (HABITAT.md: el UA real
        // de Baobabs es el del motor; aquí solo se resuelve el destino).
        public static string normalize_input(string raw) {
            var s = raw.strip();
            if (s == "")
                return s;
            if (s.has_prefix("http://") || s.has_prefix("https://")
                || s.has_prefix("file://") || s.has_prefix("about:")
                || s.has_prefix("data:") || s.has_prefix("topsites:")
                || s.has_prefix("safari-resource:") || s.has_prefix("mailto:"))
                return s;
            // Con espacios no puede ser URL: búsqueda
            if (s.contains(" "))
                return search_url(s);
            // "example.com:8080" → el análisis se hace sin el puerto
            var host_part = s.split(":")[0];
            if (looks_like_host(host_part))
                return "https://" + s;
            return search_url(s);
        }

        public static string search_url(string query) {
            return "https://duckduckgo.com/?q=" + Uri.escape_string(query);
        }

        // "https://host.edu/articulo" → "host.edu" (título de pestaña
        // provisional cuando la página no da <title>)
        public static string host_of(string url) {
            var rest = url;
            var scheme_end = url.index_of("://");
            if (scheme_end >= 0)
                rest = url.substring(scheme_end + 3);
            var slash = rest.index_of_char('/');
            if (slash >= 0)
                rest = rest.substring(0, slash);
            var query = rest.index_of_char('?');
            if (query >= 0)
                rest = rest.substring(0, query);
            return rest;
        }

        static bool looks_like_host(string h) {
            if (h == "localhost" || h.has_prefix("localhost."))
                return true;
            var parts = h.split(".");
            if (parts.length < 2)
                return false;
            foreach (var seg in parts) {
                if (seg == "")
                    return false;
                for (int i = 0; i < seg.length; i++) {
                    char c = seg[i];
                    bool ok = (c >= 'a' && c <= 'z')
                           || (c >= 'A' && c <= 'Z')
                           || (c >= '0' && c <= '9')
                           || c == '-' || c == '_';
                    if (!ok)
                        return false;
                }
            }
            // Último segmento (TLD) con 2+ caracteres
            return parts[parts.length - 1].length >= 2;
        }
    }
}
