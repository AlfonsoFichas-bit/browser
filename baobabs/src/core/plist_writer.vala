using GLib;

namespace Baobabs {
    public errordomain PlistWriteError {
        UNSUPPORTED_TYPE,
        TOO_DEEP
    }

    public class PlistWriter : GLib.Object {
        private Gee.ArrayList<GLib.Variant> objects;
        private Gee.HashMap<string, int> obj_map;

        public PlistWriter() {
            objects = new Gee.ArrayList<GLib.Variant>();
            obj_map = new Gee.HashMap<string, int>();
        }

        public static uint8[] to_bytes(GLib.Variant root) throws PlistWriteError {
            var writer = new PlistWriter();
            writer.flatten(root);

            var out_bytes = new GLib.ByteArray();
            out_bytes.append("bplist00".data);

            int ref_size = 1;
            if (writer.objects.size > 0xFF) ref_size = 2;
            if (writer.objects.size > 0xFFFF) ref_size = 4;

            int[] offsets = new int[writer.objects.size];
            for (int i = 0; i < writer.objects.size; i++) {
                offsets[i] = (int)out_bytes.len;
                writer.write_object(out_bytes, writer.objects[i], ref_size);
            }

            int offset_size = 1;
            int last_offset = (int)out_bytes.len;
            if (last_offset > 0xFF) offset_size = 2;
            if (last_offset > 0xFFFF) offset_size = 4;
            if (last_offset > 0xFFFFFF) offset_size = 8;

            int offset_table_offset = (int)out_bytes.len;
            for (int i = 0; i < writer.objects.size; i++) {
                writer.write_be(out_bytes, offsets[i], offset_size);
            }

            for (int i = 0; i < 6; i++) out_bytes.append(new uint8[] {0});
            out_bytes.append(new uint8[] { (uint8)offset_size });
            out_bytes.append(new uint8[] { (uint8)ref_size });
            writer.write_be(out_bytes, writer.objects.size, 8);
            writer.write_be(out_bytes, 0, 8);
            writer.write_be(out_bytes, offset_table_offset, 8);

            uint8[] result = new uint8[out_bytes.len];
            GLib.Memory.copy(result, out_bytes.data, out_bytes.len);
            return result;
        }

        public static void write_file(string path, GLib.Variant root) throws PlistWriteError, GLib.FileError {
            var bytes = to_bytes(root);
            GLib.FileUtils.set_data(path, bytes);
        }

        private int flatten(GLib.Variant v) throws PlistWriteError {
            string key = v.print(false);
            if (obj_map.has_key(key)) {
                return obj_map.get(key);
            }

            int idx = objects.size;
            objects.add(v);
            obj_map.set(key, idx);

            string t = v.get_type_string();
            if (t == "av") {
                for (int i = 0; i < v.n_children(); i++) {
                    flatten(v.get_child_value(i).get_variant());
                }
            } else if (t == "a{sv}") {
                for (int i = 0; i < v.n_children(); i++) {
                    var entry = v.get_child_value(i);
                    var dict_key = new GLib.Variant.string(entry.get_child_value(0).get_string());
                    flatten(dict_key);
                    flatten(entry.get_child_value(1).get_variant());
                }
            }
            return idx;
        }

        private void write_object(GLib.ByteArray out_bytes, GLib.Variant v, int ref_size) throws PlistWriteError {
            string t = v.get_type_string();
            if (t == "b") {
                if (v.get_boolean()) out_bytes.append(new uint8[] {0x09});
                else out_bytes.append(new uint8[] {0x08});
            } else if (t == "mv") {
                out_bytes.append(new uint8[] {0x00});
            } else if (t == "x") {
                int64 val = v.get_int64();
                if (val < 0) {
                    out_bytes.append(new uint8[] {0x13});
                    write_be(out_bytes, (uint64)val, 8);
                } else if (val <= 0xFF) {
                    out_bytes.append(new uint8[] {0x10});
                    write_be(out_bytes, (uint64)val, 1);
                } else if (val <= 0xFFFF) {
                    out_bytes.append(new uint8[] {0x11});
                    write_be(out_bytes, (uint64)val, 2);
                } else if (val <= 0xFFFFFFFF) {
                    out_bytes.append(new uint8[] {0x12});
                    write_be(out_bytes, (uint64)val, 4);
                } else {
                    out_bytes.append(new uint8[] {0x13});
                    write_be(out_bytes, (uint64)val, 8);
                }
            } else if (t == "d") {
                double val = v.get_double();
                out_bytes.append(new uint8[] {0x28});
                uint64 bits = double_to_uint64_bits(val);
                write_be(out_bytes, bits, 8);
            } else if (t == "t") {
                uint64 val = v.get_uint64();
                out_bytes.append(new uint8[] {0x87});
                write_be(out_bytes, val, 8);
            } else if (t == "ay") {
                var data = v.get_data_as_bytes().get_data();
                write_count(out_bytes, 0x40, data.length);
                for(int i=0; i<data.length; i++) out_bytes.append(new uint8[] {data[i]});
            } else if (t == "s") {
                string s = v.get_string();
                bool is_ascii = true;
                for (int i = 0; i < s.length; i++) {
                    if (s[i] > 127) {
                        is_ascii = false;
                        break;
                    }
                }
                if (is_ascii) {
                    write_count(out_bytes, 0x50, s.length);
                    if (s.length > 0) out_bytes.append(s.data);
                } else {
                    uint16[] u16 = null;
                    string16 utf16_str = null;
                    long items_written = 0;
                    try {
                        long items_read;
                        utf16_str = s.to_utf16(-1, out items_read, out items_written);
                        if (utf16_str != null) {
                            u16 = new uint16[items_written];
                            for (int i = 0; i < items_written; i++) {
                                u16[i] = ((uint16*)utf16_str)[i];
                            }
                        }
                    } catch (GLib.ConvertError e) { }

                    if (u16 != null) {
                        write_count(out_bytes, 0x60, u16.length);
                        for (int i = 0; i < u16.length; i++) {
                            out_bytes.append(new uint8[] { (uint8)(u16[i] >> 8), (uint8)(u16[i] & 0xFF) });
                        }
                    } else {
                        write_count(out_bytes, 0x50, 0); // fallback if decoding fails
                    }
                }
            } else if (t == "av") {
                int count = (int)v.n_children();
                write_count(out_bytes, 0xA0, count);
                for (int i = 0; i < count; i++) {
                    var child = v.get_child_value(i).get_variant();
                    int child_idx = obj_map.get(child.print(false));
                    write_be(out_bytes, (uint64)child_idx, ref_size);
                }
            } else if (t == "a{sv}") {
                int count = (int)v.n_children();
                write_count(out_bytes, 0xD0, count);
                for (int i = 0; i < count; i++) {
                    var entry = v.get_child_value(i);
                    var key_v = new GLib.Variant.string(entry.get_child_value(0).get_string());
                    int key_idx = obj_map.get(key_v.print(false));
                    write_be(out_bytes, (uint64)key_idx, ref_size);
                }
                for (int i = 0; i < count; i++) {
                    var entry = v.get_child_value(i);
                    var val_v = entry.get_child_value(1).get_variant();
                    int val_idx = obj_map.get(val_v.print(false));
                    write_be(out_bytes, (uint64)val_idx, ref_size);
                }
            } else {
                throw new PlistWriteError.UNSUPPORTED_TYPE("Unsupported type: %s".printf(t));
            }
        }

        private void write_count(GLib.ByteArray out_bytes, uint8 marker_base, int count) {
            if (count < 15) {
                out_bytes.append(new uint8[] { (uint8)(marker_base | count) });
            } else {
                out_bytes.append(new uint8[] { (uint8)(marker_base | 0x0F) });
                if (count <= 0xFF) {
                    out_bytes.append(new uint8[] { 0x10, (uint8)count });
                } else if (count <= 0xFFFF) {
                    out_bytes.append(new uint8[] { 0x11, (uint8)(count >> 8), (uint8)(count & 0xFF) });
                } else {
                    out_bytes.append(new uint8[] { 0x12, (uint8)(count >> 24), (uint8)(count >> 16), (uint8)(count >> 8), (uint8)(count & 0xFF) });
                }
            }
        }

        private void write_be(GLib.ByteArray out_bytes, uint64 val, int size) {
            for (int i = size - 1; i >= 0; i--) {
                out_bytes.append(new uint8[] { (uint8)((val >> (i * 8)) & 0xFF) });
            }
        }

        static uint64 double_to_uint64_bits(double d) {
            uint64 bits = 0;
            GLib.Memory.copy(&bits, &d, sizeof(double));
            return bits;
        }
    }
}
