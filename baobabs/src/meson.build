baobabs_core_sources = files(
  'core/config.vala',
  'core/utils.vala',
  'core/epoch.vala',
  'core/plist.vala',
  'core/plist_writer.vala',
  'engine/engine.vala',
  'engine/factory.vala',
  'ui/window.vala',
  'ui/favorites_bar.vala',
  'ui/history_view.vala',
  'bookmarks/model.vala',
  'bookmarks/loader.vala',
  'bookmarks/store.vala',
  'bookmarks/defaults.vala',
  'history/model.vala',
)

extra_includes = [include_directories('.')]

# Motor web: solo WebKitGTK en esta versión Vala.
baobabs_core_sources += files('engine/webkit.vala')

# Compilar el recurso (en data/, donde ya vive Reader.html)
gnome = import('gnome')
res = gnome.compile_resources(
  'baobabs-resources',
  '../data/style.gresource.xml',
  source_dir: '../data',
  c_name: 'baobabs_res',
)

# 1) El recurso en SU PROPIA static_library
res_lib = static_library('baobabs-resources-lib', res, dependencies: baobabs_deps)

# Libreria estatica: la enlazan el ejecutable y los tests
baobabs_core = static_library('baobabs-core',
  baobabs_core_sources,
  include_directories: extra_includes,
  dependencies: baobabs_deps,
)

# Expone libreria + vapi + header generado a los consumidores
baobabs_core_dep = declare_dependency(
  link_whole: res_lib,
  link_with: baobabs_core,
  dependencies: baobabs_deps,
  include_directories: extra_includes,
)

executable('baobabs',
  files('app.vala'),
  dependencies: baobabs_core_dep,
  install: true,
)