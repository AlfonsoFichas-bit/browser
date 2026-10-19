namespace Baobabs {
    public class Utils : GLib.Object {
        public static string generate_uuid() {
            var uuid = GLib.Uuid.string_random();
            return uuid.up();
        }
    }
}