project('baobabs', ['vala', 'c', 'cpp'],
  version: '0.1.0',
  meson_version: '>= 0.63.0',
  default_options: [
    'warning_level=1',
    'werror=false',
    'buildtype=debugoptimized',
    'cpp_std=c++17',
  ]
)

glib_dep     = dependency('glib-2.0', version: '>= 2.72')
gobject_dep  = dependency('gobject-2.0', version: '>= 2.72')
gio_dep      = dependency('gio-2.0', version: '>= 2.72')
gtk4_dep     = dependency('gtk4', version: '>= 4.10')
gee_dep      = dependency('gee-0.8')

is_windows = (host_machine.system() == 'windows')
windows_deps = []

if is_windows
  cc = meson.get_compiler('c')
  ole32_dep = cc.find_library('ole32')
  oleaut32_dep = cc.find_library('oleaut32')
  shlwapi_dep = cc.find_library('shlwapi')

  wv2_lib_dir = meson.current_source_dir() / 'src/engine/webview2'
  webview2_loader_dep = cc.find_library('WebView2Loader', dirs: [wv2_lib_dir])

  windows_deps = [ole32_dep, oleaut32_dep, shlwapi_dep, webview2_loader_dep]
endif

# --- Motor web intercambiable -------------------------------------------------
# Windows-first: WebView2 (cargado con puente C++).
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
if is_windows
  baobabs_deps += windows_deps
endif

subdir('src')

# --- Tests --------------------------------------------------------------------
subdir('tests')