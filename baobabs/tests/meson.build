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