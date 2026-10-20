namespace Baobabs {
    public class Config : GLib.Object {
        public string data_dir { get; private set; }
        public string profile_dir { get; private set; }
        public string bookmarks_path { get; private set; }
        public string history_path { get; private set; }

        private static Config? instance;

        public static Config get_instance() {
            if (instance == null) {
                instance = new Config();
            }
            return instance;
        }

        construct {
            var cfg_root = Environment.get_user_config_dir();
            this.data_dir = Path.build_filename(cfg_root, "baobabs");
            this.profile_dir = Path.build_filename(this.data_dir, "default");
            this.bookmarks_path = Path.build_filename(this.data_dir, "Bookmarks.plist");
            this.history_path = Path.build_filename(this.data_dir, "History.plist");
            DirUtils.create_with_parents(this.profile_dir, 0755);
        }
    }
}