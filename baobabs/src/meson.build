baobabs_core_sources = files(
  'core/config.vala',
  'core/utils.vala',
  'core/epoch.vala',
  'core/plist.vala',
  'core/plist_writer.vala',
  'engine/engine.vala',
  'ui/window.vala',
  'ui/toolbar.vala',
  'ui/tabs.vala',
  'bookmarks/model.vala',
  'bookmarks/loader.vala',
  'bookmarks/store.vala',
  'history/model.vala',
)

# Backend del motor: WebKitGTK en Linux (donde webkitgtk_dep.found()),
# WebView2 (stub) en el resto de plataformas. Solo se compila UNO de los dos:
# ambos definen Baobabs.create_engine().
if webkitgtk_dep.found()
  baobabs_core_sources += files('engine/webkitgtk.vala')
else
  baobabs_core_sources += files('engine/webview2.vala')
endif

# Libreria compartida: la enlazan el ejecutable y los tests
baobabs_core = static_library('baobabs-core',
  baobabs_core_sources,
  dependencies: baobabs_deps,
  vala_args: vala_args,
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
  vala_args: vala_args,
  install: true,
)
