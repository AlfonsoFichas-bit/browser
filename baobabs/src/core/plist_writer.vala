namespace Baobabs {
    // Serializador binario bplist00: contraparte de Plist.parse_bytes.
    // Escribe los MISMOS marcadores que lee el parser (ver cabecera de
    // plist.vala), por lo que el roundtrip parse→write→parse es estable.
    // Sin deduplicación de objetos: los ficheros de perfil son pequeños
    // (History.plist del perfil real: 242 B).
    //
    // Estructura del fichero:
    //   "bplist00" | objetos serializados | tabla de offsets | trailer (32 B)
    public class PlistWriter : GLib.Object {

        // Árbol plano: cada nodo tiene su índice en la lista (los offsets de
        // la tabla se rellenan al serializar; los refs de hijos usan índice).
        class Node {
            public Variant value;
            public int index;
            public int serialized_at;
            public Gee.ArrayList<Node> children;
            public bool is_dict;

            public Node(Variant v, int idx) {
                value = v;
                index = idx;
                serialized_at = 0;
                children = new Gee.ArrayList<Node>();
                is_dict = false;
            }
        }

        Gee.ArrayList<Node> nodes;

        public static uint8[] to_bytes(Variant root) throws PlistError {
            var w = new PlistWriter();
            return w.run(root);
        }

        uint8[] run(Variant root) throws PlistError {
            nodes = new Gee.ArrayList<Node>();
            build(root); // la raíz siempre es el objeto 0

            int ref_size = size_for((uint64)(nodes.size - 1));

            var body = new ByteArray();
            foreach (var n in nodes) {
                // offset absoluto: cabecera (8 B) + posición dentro del cuerpo
                n.serialized_at = 8 + (int)body.len;
                serialize(n, body, ref_size);
            }

            // La tabla de offsets va justo tras el cuerpo:
            //   offset = 8 (cabecera) + bytes ya escritos del cuerpo
            int offset_table_offset = 8 + (int)body.len;
            int max_offset = offset_table_offset + (int)body.len - 1;
            int offset_size = size_for((uint64)max_offset);

            var result = new ByteArray();
            result.append("bplist00".data);
            result.append(body.data);
            foreach (var n in nodes)
                write_be(result, (uint64)n.serialized_at, offset_size);
            result.append(trailer(nodes.size, offset_size, ref_size,
                                  offset_table_offset));
            return result.data;
        }

        // Construye el árbol de nodos en preorden (padre ANTES que hijos, que
        // es lo que exige el índice 0 = raíz del trailer).
        Node build(Variant v) throws PlistError {
            // Los valores de dict ("{sv}") y los hijos de array ("av") vienen
            // envueltos como variant ("v"): se desempaqueta aquí.
            if (v.is_of_type(new VariantType("v")))
                return build(v.get_variant());

            var n = new Node(v, nodes.size);
            nodes.add(n);

            if (v.is_of_type(new VariantType("av"))) {
                for (size_t i = 0; i < v.n_children(); i++)
                    // "av": cada hijo viene envuelto como variant ("v")
                    n.children.add(build(v.get_child_value(i).get_variant()));
            } else if (v.is_of_type(new VariantType("a{sv}"))) {
                n.is_dict = true;
                // Formato del dict en disco: refs de claves y luego de valores
                for (size_t i = 0; i < v.n_children(); i++)
                    n.children.add(build(
                        v.get_child_value(i).get_child_value(0)));
                for (size_t i = 0; i < v.n_children(); i++)
                    n.children.add(build(
                        v.get_child_value(i).get_child_value(1)));
            } else if (!is_leaf(v)) {
                throw new PlistError.UNSUPPORTED(
                    "tipo no soportado por el escritor: %s", v.get_type_string());
            }
            return n;
        }

        static bool is_leaf(Variant v) {
            return v.is_of_type(VariantType.STRING)
                || v.is_of_type(VariantType.INT64)
                || v.is_of_type(VariantType.UINT64)
                || v.is_of_type(VariantType.DOUBLE)
                || v.is_of_type(VariantType.BOOLEAN)
                || v.is_of_type(new VariantType("ay"))
                || v.is_of_type(new VariantType("mv"));
        }

        void serialize(Node n, ByteArray body, int ref_size) throws PlistError {
            var v = n.value;

            if (v.is_of_type(VariantType.BOOLEAN)) {
                body.append({ v.get_boolean() ? (uint8)0x09 : (uint8)0x08 });
                return;
            }
            if (v.is_of_type(new VariantType("mv"))) {
                body.append({ 0x00 }); // null
                return;
            }
            if (v.is_of_type(VariantType.INT64)) {
                int64 x = v.get_int64();
                int size = int_size(x);
                body.append({ (uint8)(0x10 | int_size_info(size)) });
                // complemento a dos big-endian; el cast a uint64 sign-extiende
                write_be(body, (uint64)x, size);
                return;
            }
            if (v.is_of_type(VariantType.UINT64)) {
                uint64 x = v.get_uint64();
                int size = size_for(x); // 1, 2, 4 u 8
                body.append({ (uint8)(0x80 | (size - 1)) }); // UID
                write_be(body, x, size);
                return;
            }
            if (v.is_of_type(VariantType.DOUBLE)) {
                double d = v.get_double();
                uint64 bits = 0;
                GLib.Memory.copy(&bits, &d, sizeof(double));
                body.append({ 0x23 });
                write_be(body, bits, 8);
                return;
            }
            if (v.is_of_type(new VariantType("ay"))) {
                uint8[] data = v.get_data_as_bytes().get_data();
                write_count(body, 0x40, data.length);
                body.append(data);
                return;
            }
            if (v.is_of_type(VariantType.STRING)) {
                write_string(body, v.get_string());
                return;
            }
            if (v.is_of_type(new VariantType("av"))) {
                write_count(body, 0xA0, n.children.size);
                foreach (var c in n.children)
                    write_be(body, (uint64)c.index, ref_size);
                return;
            }
            if (n.is_dict) {
                int count = n.children.size / 2; // claves + valores
                write_count(body, 0xD0, count);
                for (int i = 0; i < count; i++) // refs de claves
                    write_be(body, (uint64)n.children[i].index, ref_size);
                for (int i = count; i < count * 2; i++) // refs de valores
                    write_be(body, (uint64)n.children[i].index, ref_size);
                return;
            }
            throw new PlistError.UNSUPPORTED(
                "tipo no soportado por el escritor: %s", v.get_type_string());
        }

        void write_string(ByteArray body, string s) {
            if (is_ascii(s)) {
                write_count(body, 0x50, s.length);
                body.append(s.data); // ASCII: bytes UTF-8 == code units
                return;
            }
            // UTF-16BE (marcador 0x6); mismo codificado que lee el parser
            var units = utf16be_units(s);
            write_count(body, 0x60, units.length);
            foreach (var u in units) {
                body.append({ (uint8)(u >> 8), (uint8)(u & 0xFF) });
            }
        }

        static bool is_ascii(string s) {
            for (int i = 0; i < s.length; i++) {
                // char es con signo: sin el cast, 0xC3 lee como -61 y
                // "Español" pasaría por ASCII (bug ya cubierto en tests)
                if ((uint8)s[i] >= 0x80)
                    return false;
            }
            return true;
        }

        static uint16[] utf16be_units(string s) {
            var units = new Gee.ArrayList<uint16>();
            int i = 0;
            unichar c;
            while (s.get_next_char(ref i, out c)) {
                if (c > 0xFFFF) {
                    // par de sustitución para caracteres SMP
                    uint32 v = c - 0x10000;
                    units.add((uint16)(0xD800 + (v >> 10)));
                    units.add((uint16)(0xDC00 + (v & 0x3FF)));
                } else {
                    units.add((uint16)c);
                }
            }
            return units.to_array();
        }

        // Marcador (kind = nibble alto: 0x50 ASCII, 0xD0 dict...) + conteo;
        // si count >= 15: conteo extendido (nibble 0xF) 0x1m + entero
        void write_count(ByteArray body, uint8 kind, int64 count) {
            if (count < 15) {
                body.append({ (uint8)(kind | (uint8)count) });
                return;
            }
            body.append({ (uint8)(kind | 0x0F) });
            int size = size_for((uint64)count);
            body.append({ (uint8)(0x10 | int_size_info(size)) });
            write_be(body, (uint64)count, size);
        }

        static int int_size(int64 x) {
            if (x >= -128 && x <= 127) return 1;
            if (x >= -32768 && x <= 32767) return 2;
            if (x >= -2147483648 && x <= 2147483647) return 4;
            return 8;
        }

        // log2 del tamaño (1→0, 2→1, 4→2, 8→3): nibble bajo del marcador
        static int int_size_info(int size) {
            switch (size) {
            case 1: return 0;
            case 2: return 1;
            case 4: return 2;
            default: return 3;
            }
        }

        // Tamaño en bytes (1, 2, 4 u 8) para representar el valor dado
        static int size_for(uint64 v) {
            if (v <= 0xFF) return 1;
            if (v <= 0xFFFF) return 2;
            if (v <= 0xFFFFFFFF) return 4;
            return 8;
        }

        static void write_be(ByteArray body, uint64 v, int size) {
            for (int i = size - 1; i >= 0; i--)
                body.append({ (uint8)((v >> (8 * i)) & 0xFF) });
        }

        static uint8[] trailer(int num_objects, int offset_size, int ref_size,
                               int offset_table_offset) {
            var t = new uint8[32];
            t[6] = (uint8)offset_size;
            t[7] = (uint8)ref_size;
            write_be_into(t, 8, (uint64)num_objects);
            write_be_into(t, 16, 0); // topObject: la raíz es siempre el 0
            write_be_into(t, 24, (uint64)offset_table_offset);
            return t;
        }

        static void write_be_into(uint8[] dest, int at, uint64 v) {
            for (int i = 7; i >= 0; i--)
                dest[at + (7 - i)] = (uint8)((v >> (8 * i)) & 0xFF);
        }
    }
}
