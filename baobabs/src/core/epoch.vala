namespace Baobabs {
    // Safari 5.1 usa epoch Cocoa: 2001-01-01 00:00:00 GMT
    public const int64 COCOA_EPOCH_OFFSET = 978307200;

    public class EpochUtils : GLib.Object {
        public static int64 cocoa_to_unix(double cocoa_seconds) {
            return (int64)cocoa_seconds + COCOA_EPOCH_OFFSET;
        }

        public static double unix_to_cocoa(int64 unix_seconds) {
            return (double)(unix_seconds - COCOA_EPOCH_OFFSET);
        }
    }
}