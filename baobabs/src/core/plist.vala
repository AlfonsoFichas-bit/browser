namespace Baobabs {
    public errordomain PlistError {
        INVALID_FORMAT,
        UNSUPPORTED
    }

    // Parser de binary plist (bplist00): el formato real de los plists del
    // perfil de Safari 5.1.7 en Windows (Bookmarks, History, TopSites,
    // ReadingList). Convierte a GLib.Variant, fiel al formato:
    //   dict       -> "a{sv}"     array/set -> "av"
    //   string     -> "s"         int       -> "x" (int64)
    //   real/fecha -> "d"         UID       -> "t"   (fecha: segundos Cocoa)
    //   data       -> "ay"        null      -> "mv" (maybe vacio)
    public class Plist : GLib.Object {
        const int TRAILER_SIZE = 32;
        const int HEADER_SIZE = 8;

        uint8[] data;
        int offset_size;
        int ref_size;
        int64 num_objects;
        int64 top_object;
        int64 offset_table_offset;
        int64[] offsets;
        Variant?[] cache;
        bool[] busy;

        public static bool looks_binary(uint8[] bytes) {
            return bytes.length > HEADER_SIZE
                && bytes[0] == 'b' && bytes[1] == 'p' && bytes[2] == 'l'
                && bytes[3] == 'i' && bytes[4] == 's' && bytes[5] == 't';
        }

        public static Variant parse_bytes(uint8[] bytes) throws PlistError {
            var p = new Plist();
            p.load_header(bytes);
            return p.parse_object((int)p.top_object);
        }

        public static Variant parse_file(string path) throws PlistError, GLib.FileError {
            uint8[] bytes;
            GLib.FileUtils.get_data(path, out bytes);
            return parse_bytes(bytes);
        }

        // Trailer de 32 bytes al final del fichero:
        //   [0..5] uso libre, [6] offsetIntSize, [7] objectRefSize,
        //   [8..15] numObjects, [16..23] topObject, [24..31] offsetTableOffset
        void load_header(uint8[] bytes) throws PlistError {
            data = bytes;
            if (data.length < HEADER_SIZE + TRAILER_SIZE)
                throw new PlistError.INVALID_FORMAT("bplist demasiado corto");
            if (!looks_binary(data))
                throw new PlistError.INVALID_FORMAT("cabecera no es bplist");

            int t = data.length - TRAILER_SIZE;
            offset_size = data[t + 6];
            ref_size = data[t + 7];
            num_objects = read_be(t + 8, 8);
            top_object = read_be(t + 16, 8);
            offset_table_offset = read_be(t + 24, 8);

            if (offset_size < 1 || offset_size > 8 || ref_size < 1 || ref_size > 8)
                throw new PlistError.INVALID_FORMAT("tamano de entrada invalido en trailer");
            if (num_objects < 1 || top_object < 0 || top_object >= num_objects)
                throw new PlistError.INVALID_FORMAT("tabla de objetos invalida");
            if (offset_table_offset < HEADER_SIZE || offset_table_offset >= t)
                throw new PlistError.INVALID_FORMAT("tabla de offsets invalida");

            offsets = new int64[num_objects];
            cache = new Variant?[num_objects];
            busy = new bool[num_objects];
            for (int64 i = 0; i < num_objects; i++) {
                offsets[i] = read_be((int)offset_table_offset + (int)i * offset_size, offset_size);
                if (offsets[i] < HEADER_SIZE || offsets[i] >= t)
                    throw new PlistError.INVALID_FORMAT("offset de objeto invalido");
            }
        }

        Variant parse_object(int idx) throws PlistError {
            if (idx < 0 || (int64)idx >= num_objects)
                throw new PlistError.INVALID_FORMAT("indice de objeto fuera de rango");
            if (cache[idx] != null)
                return cache[idx];
            if (busy[idx])
                throw new PlistError.INVALID_FORMAT("referencia circular en objetos");
            busy[idx] = true;
            Variant v = parse_at((int)offsets[idx]);
            cache[idx] = v;
            busy[idx] = false;
            return v;
        }

        Variant parse_at(int off) throws PlistError {
            need(off, 1);
            uint8 marker = data[off];
            uint8 kind = marker >> 4;
            uint8 info = marker & 0x0F;
            int64 count;
            int body;

            switch (kind) {
            case 0x0: // simple: null / false / true
                if (info == 0x8)
                    return new Variant.boolean(false);
                if (info == 0x9)
                    return new Variant.boolean(true);
                if (info == 0x0) {
                    // maybe vacío = "null"; se representa como "mv"
                    // (maybe de variant sin hijo), que el writer emite como 0x00
                    return new Variant.maybe(new VariantType("v"), null);
                }
                throw new PlistError.INVALID_FORMAT(
                    "marcador simple desconocido: %#02x", marker);
            case 0x1: // entero con signo big-endian, 2^info bytes
                int size = 1 << info;
                if (size == 16) {
                    // 128-bit: muy raro; nos quedamos con la parte con signo
                    int64 hi = read_be(off + 1, 8);
                    return new Variant.int64(hi != 0 ? hi : read_be(off + 9, 8));
                }
                return new Variant.int64(read_be_signed(off + 1, size));
            case 0x2: // real
                if (info == 4)
                    return new Variant.double(uint32_bits_to_double((uint32)read_be(off + 1, 4)));
                if (info == 8)
                    return new Variant.double(uint64_bits_to_double((uint64)read_be(off + 1, 8)));
                throw new PlistError.INVALID_FORMAT("real de tamano no soportado");
            case 0x3: // fecha: double, segundos desde 2001-01-01 GMT (epoch Cocoa)
                if (info != 3)
                    throw new PlistError.INVALID_FORMAT("marcador de fecha invalido");
                return new Variant.double(uint64_bits_to_double((uint64)read_be(off + 1, 8)));
            case 0x4: // data
                body = read_count(off, info, out count);
                need(body, count);
                uint8[] chunk = data[body : body + (int)count];
                return new Variant.from_bytes(new VariantType("ay"), new Bytes.take(chunk), true);
            case 0x5: // string ASCII
                body = read_count(off, info, out count);
                need(body, count);
                return new Variant.string(decode_ascii(body, count));
            case 0x6: // string UTF-16BE (2 bytes por unidad de codigo)
                body = read_count(off, info, out count);
                return new Variant.string(decode_utf16be(body, count));
            case 0x8: // UID (1..8 bytes sin signo)
                need(off, 2);
                int uid_size = info + 1;
                return new Variant.uint64((uint64)read_be(off + 1, uid_size));
            case 0xA: // array
            case 0xC: // set (tratado como array; convencion real de CF)
                body = read_count(off, info, out count);
                need(body, count * ref_size);
                var ab = new VariantBuilder(new VariantType("av"));
                for (int64 i = 0; i < count; i++)
                    // "av": cada hijo debe ir envuelto como variant ("v")
                    ab.add_value(new Variant.variant(
                        parse_object((int)read_be(body + (int)i * ref_size, ref_size))));
                return ab.end();
            case 0xD: // dict: primero count refs de claves, luego count de valores
                body = read_count(off, info, out count);
                need(body, count * ref_size * 2);
                var db = new VariantBuilder(new VariantType("a{sv}"));
                for (int64 i = 0; i < count; i++) {
                    Variant key = parse_object((int)read_be(body + (int)i * ref_size, ref_size));
                    string ks;
                    if (key.is_of_type(VariantType.STRING))
                        ks = key.get_string();
                    else if (key.is_of_type(VariantType.UINT64))
                        ks = key.get_uint64().to_string();
                    else
                        throw new PlistError.INVALID_FORMAT("clave de dict no soportada");
                    int voff = body + (int)count * ref_size + (int)i * ref_size;
                    db.add("{sv}", ks, parse_object((int)read_be(voff, ref_size)));
                }
                return db.end();
            default:
                throw new PlistError.INVALID_FORMAT("marcador 0x%02X no soportado", marker);
            }
        }

        // Tamano de payload: si info == 0xF, el tamano real es un entero que
        // sigue al marcador (marcador 0x1n con 2^n bytes big-endian).
        int read_count(int off, uint8 info, out int64 count) throws PlistError {
            if (info != 0x0F) {
                count = info;
                return off + 1;
            }
            need(off, 2);
            uint8 m = data[off + 1];
            if ((m >> 4) != 0x1)
                throw new PlistError.INVALID_FORMAT("conteo extendido invalido");
            int size = 1 << (m & 0x0F);
            count = read_be(off + 2, size);
            return off + 2 + size;
        }

        int64 read_be(int off, int size) throws PlistError {
            need(off, size);
            uint64 u = 0;
            for (int i = 0; i < size; i++)
                u = (u << 8) | data[off + i];
            return (int64)u;
        }

        int64 read_be_signed(int off, int size) throws PlistError {
            uint64 u = (uint64)read_be(off, size);
            if (size < 8) {
                uint64 sign = (uint64)1 << (size * 8 - 1);
                if ((u & sign) != 0)
                    u |= ~(((uint64)1 << (size * 8)) - 1);
            }
            return (int64)u;
        }

        void need(int off, int64 n) throws PlistError {
            if (off < 0 || n < 0 || (int64)off + n > data.length)
                throw new PlistError.INVALID_FORMAT("lectura fuera de limites");
        }

        string decode_ascii(int off, int64 count) {
            var sb = new GLib.StringBuilder();
            for (int64 i = 0; i < count; i++)
                sb.append_c((char)data[off + i]);
            return sb.str;
        }

        string decode_utf16be(int off, int64 units) throws PlistError {
            need(off, units * 2);
            var sb = new GLib.StringBuilder();
            int64 i = 0;
            while (i < units) {
                uint16 cu = (uint16)((data[off] << 8) | data[off + 1]);
                off += 2;
                i++;
                // pares de sustitucion (surrogates) para caracteres SMP
                if (cu >= 0xD800 && cu <= 0xDBFF && i < units) {
                    uint16 lo = (uint16)((data[off] << 8) | data[off + 1]);
                    if (lo >= 0xDC00 && lo <= 0xDFFF) {
                        uint32 cp = 0x10000 + (((uint32)cu - 0xD800) << 10) + ((uint32)lo - 0xDC00);
                        sb.append_unichar((unichar)cp);
                        off += 2;
                        i++;
                        continue;
                    }
                }
                sb.append_unichar((unichar)cu);
            }
            return sb.str;
        }

        // Reinterpreta bits como double/float (los reales del bplist son
        // IEEE 754 big-endian)
        static double uint64_bits_to_double(uint64 bits) {
            double d = 0;
            GLib.Memory.copy(&d, &bits, sizeof(double));
            return d;
        }

        static double uint32_bits_to_double(uint32 bits) {
            float f = 0;
            GLib.Memory.copy(&f, &bits, sizeof(float));
            return (double)f;
        }
    }
}
