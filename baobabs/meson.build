project('baobabs', ['vala', 'c'],
  version: '0.1.0',
  meson_version: '>= 0.63.0',
  default_options: [
    'warning_level=1',
    'werror=false',
    'buildtype=debugoptimized',
  ]
)

glib_dep     = dependency('glib-2.0', version: '>= 2.72')
gobject_dep  = dependency('gobject-2.0', version: '>= 2.72')
gio_dep      = dependency('gio-2.0', version: '>= 2.72')
gtk4_dep     = dependency('gtk4', version: '>= 4.10')
gee_dep      = dependency('gee-0.8')

# --- Motor web intercambiable -------------------------------------------------
# Windows-first: WebView2 (cargado dinámicamente, sin dependencia de build).
# Linux futuro: WebKitGTK (detectado aquí cuando exista).
webkitgtk_dep = disabler()

if host_machine.system() == 'linux'
  webkitgtk_dep = dependency('webkitgtk-6.0', version: '>= 2.42', required: false)
  if not webkitgtk_dep.found()
    webkitgtk_dep = dependency('webkit2gtk-4.1', version: '>= 2.42', required: false)
  endif
endif

# --- Dependencias opcionales por fase ----------------------------------------
sqlite_dep    = dependency('sqlite3', required: false)
libxml_dep    = dependency('libxml-2.0', required: false)
libsoup_dep   = dependency('libsoup-3.0', required: false)

baobabs_deps = [glib_dep, gobject_dep, gio_dep, gtk4_dep, gee_dep]
if webkitgtk_dep.found()
  baobabs_deps += webkitgtk_dep
endif

subdir('src')

# --- Tests --------------------------------------------------------------------
subdir('tests')