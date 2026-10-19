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
# Linux: WebKitGTK 6 (GTK4) es OBLIGATORIO. El antiguo fallback webkit2gtk-4.1
# se eliminó a propósito: es GTK3 y no se puede embeber en una ventana GTK4.
# Windows (fase 4): WebView2 via stub condicional en src/meson.build.
webkitgtk_dep = dependency('webkitgtk-6.0', version: '>= 2.42',
                           required: host_machine.system() == 'linux')

# --- UI: Granite (librería de widgets de elementary OS, opcional) ------------
# Si está, se define el símbolo HAVE_GRANITE para los #if de Vala.
granite_dep = dependency('granite-7', required: false)

# --- Dependencias opcionales por fase ----------------------------------------
sqlite_dep    = dependency('sqlite3', required: false)
libxml_dep    = dependency('libxml-2.0', required: false)
libsoup_dep   = dependency('libsoup-3.0', required: false)

baobabs_deps = [glib_dep, gobject_dep, gio_dep, gtk4_dep, gee_dep]
if webkitgtk_dep.found()
  baobabs_deps += webkitgtk_dep
endif
if granite_dep.found()
  baobabs_deps += granite_dep
endif

vala_args = []
if granite_dep.found()
  vala_args += ['--define=HAVE_GRANITE']
endif

subdir('src')

# --- Tests --------------------------------------------------------------------
subdir('tests')