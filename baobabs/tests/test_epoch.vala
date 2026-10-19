using Baobabs;

int main(string[] args) {
    // Safari 5.1.7: lastVisitedDate de History.plist usa epoch Cocoa (2001-01-01)
    // 814053320.7 (ejemplo de HABITAT.md) -> 2001-06-13 ~21:42 UTC
    double cocoa = 814053320.7;
    int64 unix_t = EpochUtils.cocoa_to_unix(cocoa);
    assert(unix_t == 814053320 + COCOA_EPOCH_OFFSET);

    // Round-trip con tolerancia: Unix tiene precision de 1s, la fraccion se trunca
    double back = EpochUtils.unix_to_cocoa(unix_t);
    double diff = back - cocoa;
    if (diff < 0) {
        diff = -diff;
    }
    assert(diff < 1.0);

    // Round-trip exacto con valor sin fraccion
    double cocoa_int = 814053320.0;
    int64 unix_round = EpochUtils.cocoa_to_unix(cocoa_int);
    double exact = EpochUtils.unix_to_cocoa(unix_round);
    assert(exact == cocoa_int);

    // 2001-01-01 00:00:00 UTC Cocoa = 978307200 Unix
    assert(EpochUtils.cocoa_to_unix(0) == COCOA_EPOCH_OFFSET);

    // UUID en mayúsculas (formato WebBookmarkUUID de Safari)
    var uuid = Utils.generate_uuid();
    assert(uuid == uuid.up());
    assert(uuid.length == 36);

    print("epoch + uuid tests OK\n");
    return 0;
}