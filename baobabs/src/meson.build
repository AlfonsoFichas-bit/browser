baobabs_core_sources = files(
  'core/config.vala',
  'core/utils.vala',
  'core/epoch.vala',
  'core/plist.vala',
  'engine/engine.vala',
  'engine/factory.vala',
  'ui/window.vala',
  'bookmarks/model.vala',
  'bookmarks/loader.vala',
  'bookmarks/store.vala',
  'history/model.vala',
)

extra_includes = [include_directories('.')]

if is_windows
  baobabs_core_sources += files(
    'engine/webview2.vala',
    'engine/webview2/webview2_bridge.vapi',
    'engine/webview2/webview2_bridge.cpp',
    'engine/webview2/webview2_bridge_helper.c',
  )

  # Linux (futuro): baobabs_core_sources += files('engine/webkit.vala')
  extra_includes += include_directories(
    '../deps/webview2/pkg/build/native/include',
    'engine/webview2',
  )

  # Copiar WebView2Loader.dll junto al ejecutable en el directorio de salida
  configure_file(
    input: meson.project_source_root() / 'deps/webview2/pkg/runtimes/win-x64/native/WebView2Loader.dll',
    output: 'WebView2Loader.dll',
    copy: true,
  )
endif

# Libreria estatica: la enlazan el ejecutable y los tests
baobabs_core = static_library('baobabs-core',
  baobabs_core_sources,
  include_directories: extra_includes,
  dependencies: baobabs_deps,
)

# Expone libreria + vapi + header generado a los consumidores
baobabs_core_dep = declare_dependency(
  link_with: baobabs_core,
  dependencies: baobabs_deps,
  include_directories: extra_includes,
)

executable('baobabs',
  files('app.vala'),
  dependencies: baobabs_core_dep,
  install: true,
)