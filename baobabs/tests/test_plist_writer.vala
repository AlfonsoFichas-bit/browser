using GLib;
using Baobabs;

static string[] cli_args;

public static int main(string[] args) {
    Test.init(ref args);
    cli_args = args;

    Test.add_func("/plist_writer/synthetic_roundtrip", () => {
        var builder = new VariantBuilder(new VariantType("a{sv}"));
        builder.add("{sv}", "string_ascii", new Variant.string("hello world"));
        builder.add("{sv}", "string_utf16", new Variant.string("hola cañón español"));
        builder.add("{sv}", "int_small", new Variant.int64(42));
        builder.add("{sv}", "int_large", new Variant.int64(0x123456789ABCDEF));
        builder.add("{sv}", "bool_true", new Variant.boolean(true));
        builder.add("{sv}", "bool_false", new Variant.boolean(false));
        builder.add("{sv}", "double_val", new Variant.double(3.14159));

        var arr_builder = new VariantBuilder(new VariantType("av"));
        for (int i = 0; i < 20; i++) { // Test extended count
            arr_builder.add_value(new Variant.variant(new Variant.string("item " + i.to_string())));
        }
        builder.add("{sv}", "array_large", arr_builder.end());

        var original = builder.end();

        try {
            var bytes = PlistWriter.to_bytes(original);
            var reloaded = Plist.parse_bytes(bytes);

            assert(original.print(true) == reloaded.print(true));
        } catch (Error e) {
            Test.fail();
            printerr("Synthetic roundtrip failed: %s\n", e.message);
        }
    });

    Test.add_func("/plist_writer/real_roundtrip", () => {
        if (cli_args.length < 2) {
            printerr("Missing fixture directory argument\n");
            Test.fail();
            return;
        }

        string fixture_dir = cli_args[1];
        string history_path = Path.build_filename(fixture_dir, "..", "..", "..", "safari", "History.plist");

        try {
            var original = Plist.parse_file(history_path);
            var bytes = PlistWriter.to_bytes(original);
            var reloaded = Plist.parse_bytes(bytes);

            assert(original.print(true) == reloaded.print(true));
        } catch (Error e) {
            Test.fail();
            printerr("Real roundtrip failed: %s\n", e.message);
        }
    });

    return Test.run();
}
