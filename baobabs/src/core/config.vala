namespace Baobabs {
    public class Config : GLib.Object {
        public string data_dir { get; private set; }
        public string profile_dir { get; private set; }

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
            DirUtils.create_with_parents(this.profile_dir, 0755);
        }

        // Mismos nombres de fichero que el perfil de Safari 5.1
        // (HABITAT.md 1.1): el mismo esquema, directorio propio de Baobabs.
        public string history_path {
            owned get { return Path.build_filename(profile_dir, "History.plist"); }
        }

        public string bookmarks_path {
            owned get { return Path.build_filename(profile_dir, "Bookmarks.plist"); }
        }

        public string topsites_path {
            owned get { return Path.build_filename(profile_dir, "TopSites.plist"); }
        }

        public string reading_list_path {
            owned get { return Path.build_filename(profile_dir, "ReadingList.plist"); }
        }
    }
}
