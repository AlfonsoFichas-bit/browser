baobabs_core_sources = files(
  'core/config.vala',
  'core/utils.vala',
  'core/epoch.vala',
  'core/plist.vala',
  'engine/engine.vala',
  'engine/webview2.vala',
  'ui/window.vala',
  'bookmarks/model.vala',
  'bookmarks/loader.vala',
  'bookmarks/store.vala',
  'history/model.vala',
)

# Libreria compartida: la enlazan el ejecutable y los tests
baobabs_core = static_library('baobabs-core',
  baobabs_core_sources,
  dependencies: baobabs_deps,
)

# Expone libreria + vapi + header generado a los consumidores
baobabs_core_dep = declare_dependency(
  link_with: baobabs_core,
  dependencies: baobabs_deps,
  include_directories: include_directories('.'),
)

executable('baobabs',
  files('app.vala'),
  dependencies: baobabs_core_dep,
  install: true,
)