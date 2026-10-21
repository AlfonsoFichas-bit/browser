if is_windows
  configure_file(
    input: meson.project_source_root() / 'deps/webview2/pkg/runtimes/win-x64/native/WebView2Loader.dll',
    output: 'WebView2Loader.dll',
    copy: true,
  )
endif

# Tests (epoch conversion, uuid, bookmarks model)
test_epoch = executable('test-epoch',
  files('test_epoch.vala'),
  dependencies: baobabs_core_dep,
)

test('epoch + uuid', test_epoch)

# Parser bplist00 + loader de bookmarks contra plists REALES del perfil
test_plist = executable('test-plist',
  files('test_plist.vala'),
  dependencies: baobabs_core_dep,
)

test('plist + bookmarks loader', test_plist,
  args: [meson.current_source_dir() / 'fixtures'],
)

test_plist_writer = executable('test-plist-writer',
  files('test_plist_writer.vala'),
  dependencies: baobabs_core_dep,
)

test('plist writer round-trip', test_plist_writer,
  args: [meson.current_source_dir() / 'fixtures'],
)

if not is_windows
  test_webkit = executable('test-webkit',
    files('test_webkit_engine.vala'),
    dependencies: baobabs_core_dep,
  )
  test('webkit engine', test_webkit)
endif