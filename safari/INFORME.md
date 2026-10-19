# Inspección y clon de `C:\Program Files (x86)\Safari`

**Fecha:** 2026-10-18
**Herramienta:** REA (MCP `rea-agents@6.7.0`) + parser PE propio
**Objetivo:** inspeccionar y clonar el navegador Safari instalado en Windows

---

## 1. Clon de trabajo (opción A: copiar archivos)

Directorio aislado: `C:\Users\punks\TGZ\safari\inspect-safari\`

| Archivo | Tamaño | Compilación (UTC) |
|---|---:|---|
| `Safari.exe` | 2.388.336 | 2012-04-25 16:50:38 |
| `WebKit.dll` | 8.700.776 | 2012-04-25 02:40:23 |
| `JavaScriptCore.dll` | 1.468.264 | 2012-04-25 00:01:20 |
| `WebKitQuartzCoreAdditions.dll` | 159.080 | 2012-04-25 00:07:35 |
| `WebKit2WebProcess.exe` | 14.184 | 2012-04-25 02:40:45 |
| **`Safari.dll`** | **8.319.336** | 2012-04-25 16:49:38 |

Los originales en `Program Files` **no se modificaron**.

---

## 2. Identidad del objetivo (REA)

```
open_binary → { format: "pe", kind: "executable", architecture: "x86" }
SHA-256: f534e35773bc9beaca5e81cc8315c7152a465a296ee6ef0d28af58be251cd1ef
```

**Evidencia REA:** `ev_105a59fe68d2a469df490d2399bad8c86e82b16bbcc0249c17a48e15bf624ced`
(`inspect_pe_resources` — cobertura **complete**, 187 entradas examinadas, 91 recursos)

| Campo | Valor |
|---|---|
| Formato | PE32 |
| Machine | `332` = `0x14C` (x86 / i386) |
| Recursos | 91 (`RT_ICON` 3, `RT_MENU` 6, `RT_GROUP_ICON` 14, `RT_VERSION` 16, `RT_MANIFEST` 24) |

### Recurso `RT_VERSION` (leído del payload, offset 2377448, 716 bytes)

```
FileDescription  : Safari
FileVersion      : 534.57.2
CompanyName      : Apple Inc.
InternalName     : Safari
LegalCopyright   : Copyright Apple Inc. 2007-2012
OriginalFilename : Safari.exe
ProductName      : Safari
ProductVersion   : 5.1.7 (7534.57.2)
Locale           : 040904b0 (en-US, Unicode)
```

> **Este es Safari 5.1.7 para Windows** — la última versión que Apple publicó
> antes de discontinuar Safari en Windows (2012).

---

## 3. Cabeceras PE (parser propio, no REA)

> Nota: REA no dispone de provider de análisis en Windows sin Ghidra, por lo que
> esta sección procede de un parser PE propio en `inspect-safari/pe-inspect.mjs`.

| Binario | Formato | ImageBase | EntryPoint RVA | Características | Secciones |
|---|---|---|---|---|---|
| Safari.exe | PE32 x86 | `0x400000` | `0x1733` | `0x102` | .text .rdata .data .rsrc .reloc |
| WebKit.dll | PE32 x86 | `0x10000000` | `0x69145A` | `0x2102` | .text .rdata .data **.unwante** .rsrc .reloc |
| JavaScriptCore.dll | PE32 x86 | `0x10000000` | `0x98A56` | `0x2102` | .text .rdata .data **.unwante** .rsrc .reloc |
| WebKitQuartzCoreAdditions.dll | PE32 x86 | `0x10000000` | `0x1AF94` | `0x2102` | .text .rdata .data .rsrc .reloc |
| WebKit2WebProcess.exe | PE32 x86 | `0x400000` | `0x13BF` | `0x102` | .text .rdata .data .rsrc .reloc |

`0x2102` = EXECUTABLE_IMAGE | LARGE_ADDRESS_AWARE | DLL
`0x102` = EXECUTABLE_IMAGE | LARGE_ADDRESS_AWARE

---

## 4. Imports / Exports

### Safari.exe — 4 DLLs, 52 funciones, 0 exports

```
SHLWAPI.dll      2    KERNEL32.dll   20    USER32.dll   1    MSVCR80.dll   29
```

> **Safari.exe es un *shim/lancador*.** Un ejecutable de 2,3 MB con solo 52
> imports indica que la funcionalidad real se carga dinámicamente
> (`LoadLibrary`/`GetProcAddress`) o reside en `Safari.dll` (clonado
> posteriormente — ver sección 7).

### WebKit2WebProcess.exe — 3 DLLs, 46 funciones, 0 exports

```
SHLWAPI.dll   2    KERNEL32.dll   18    MSVCR80.dll   26
```

> Otro shim: es el **proceso de renderizado** de la arquitectura multiproceso
> de WebKit2 (contenido en proceso separado).

### WebKit.dll — 26 DLLs, ~1.500 funciones, 841 exports

Dependencias principales (por nº de funciones importadas):

| DLL | Funciones | Rol |
|---|---:|---|
| `JavaScriptCore.dll` | 380 | Motor JavaScript |
| `CoreGraphics.dll` | 249 | Renderizado 2D |
| `CoreFoundation.dll` | 177 | Runtime base de Apple |
| `CFNetwork.dll` | 174 | Red (HTTP/TLS) |
| `QuartzCore.dll` | 144 | Compositing / Core Animation |
| `USER32.dll` | 119 | Win32 UI |
| `KERNEL32.dll` | 97 | Sistema |
| `libicuuc.dll` | 51 | Unicode |
| `libxml2.dll` | 49 | Parser HTML/XML |
| `GDI32.dll` | 48 | Gráficos |
| otras | — | `ole32`, `SHLWAPI`, `ADVAPI32`, `SHELL32`, `CRYPT32`, `zlib1`, `libdispatch`, `libicuin`, `d3d9`, `MSVCP80`, `MSVCR80`, `OLEAUT32`, `RPCRT4`, `comdlg32`, `WINMM`, `WebKitQuartzCoreAdditions` |

Exports: 841, mayoritariamente símbolos C++ mangleados de los namespaces
`WTF::` y `JSC::` (`WTF::Mutex`, `WTF::ThreadCondition`, `WTF::callOnMainThread`,
`WTF::createThread`, …).

### JavaScriptCore.dll — 12 DLLs, ~147 funciones, 546 exports

```
MSVCR80 62 | KERNEL32 46 | MSVCP80 7 | libicuin 6 | libicuuc 5
CoreFoundation 3 | ADVAPI32 3 | pthreadVC2 4 | USER32 5 | OLEAUT32 2 | WINMM 2 | GDI32 2
```

546 exports C++ mangleados: `JSC::` (`JSString`, `JSArray`, `RegExpObject`,
`JSGlobalObject`, `JSLock`, `Structure`, `ExecutableAllocator`…) y `WTF::`
(`CString`, `Collator`, `MD5`, `SHA1`, `Mutex`, `RefCountedLeakCounter`).

### WebKitQuartzCoreAdditions.dll — 11 DLLs, 19 exports

API plana `WKCACF*` (Windows WebKit Quartz Core Additions):
`WKCACFViewCreate`, `WKCACFViewDraw`, `WKCACFViewFlushContext`,
`WKCACFImageCopyFileMapping`, `WKCACFViewSetLayer`, …

---

## 5. Sección `.unwante` — resuelto

**Observación:** `WebKit.dll` y `JavaScriptCore.dll` contienen una sección
llamada exactamente `.unwante` (bytes `2E 75 6E 77 61 6E 74 65`, 8 caracteres
**sin terminador nul**). Ningún otro binario de la instalación la tiene.

Es un **truncamiento**: PE limita los nombres de sección a 8 bytes, y el nombre
original era `.unwanted` (9 caracteres).

### Contenido

`JavaScriptCore.dll` (28 bytes útiles, image base `0x10000000`):

```
00 B8 09 10   -> 0x1009B800
10 B8 09 10   -> 0x1009B810
20 B8 09 10   -> 0x1009B820
30 B8 09 10   -> 0x1009B830
40 B8 09 10   -> 0x1009B840
50 B8 09 10   -> 0x1009B850
60 B8 09 10   -> 0x1009B860
00 00 00 00   -> terminador
```

Son **7 punteros a código** dentro de `.text`, espaciados 0x10 (16 B).

### Código al que apuntan (RVA 0x9B800…)

```
RVA 0x09B800  68 70 B8 09 10  E8 0D D4 FF FF  59 C3 CC CC CC CC
RVA 0x09B810  68 A0 B8 09 10  E8 FD D3 FF FF  59 C3 CC CC CC CC
RVA 0x09B820  68 D0 B8 09 10  E8 ED D3 FF FF  59 C3 CC CC CC CC
RVA 0x09B830  68 00 B9 09 10  E8 DD D3 FF FF  59 C3 CC CC CC CC
RVA 0x09B840  68 30 B9 09 10  E8 CD D3 FF FF  59 C3 CC CC CC CC
RVA 0x09B850  68 60 B9 09 10  E8 BD D3 FF FF  59 C3 CC CC CC CC
RVA 0x09B860  68 90 B9 09 10  E8 AD D3 FF FF  59 C3 CC CC CC CC
```

Descodificado de cada thunk de 16 bytes:

```asm
push  <contexto distinto por thunk>   ; 0x1009B870, +0x30, +0x60, ...
call  0x098C17                        ; handler común
pop   ecx
ret
int3  int3  int3  int3                ; relleno de alineación a 16 bytes
```

**Conclusión:** es una **tabla de *callback stubs*** — 7 trampolines con
contexto propio que invocan un único handler. Artefacto legítimo del build de
WebKit/JavaScriptCore, **no es código malicioso**.

*Estado:* el destino exacto del `call 0x098C17` queda por confirmar con Ghidra.

---

## 6. Análisis profundo con Ghidra (REA)

Ghidra 12.1.4 instalado en `C:\Users\punks\tools\ghidra_12.1.4_PUBLIC` y
configurado vía `GHIDRA_INSTALL_DIR`.

> Nota operativa: el acceso MCP de REA a Ghidra quedó operativo tras corregir
> la registración (clave `environment`, no `env`) y subir los timeouts
> (`mcp.timeout`: arranque 600 s / ejecución 1800 s). El análisis de
> `Safari.dll` exigió además `GHIDRA_HEADLESS_MAXMEM=8G` y deshabilitar el
> analizador `x86 Constant Reference Analyzer` (evita el OOM de
> `X86Analyzer.flowConstants`).

### Overview (Evidencia `ev_fb7c3e0dd25b83df1dccd1ea1d0d2a1301eb66c69f7825c69d91b7f634e86bf0`)

| Segmento | Rango | Tamaño |
|---|---|---:|
| Headers | `0x400000–0x400400` | 1.024 |
| `.text` | `0x401000–0x401e00` | **3.584** |
| `.rdata` | `0x402000–0x402c00` | 3.072 |
| `.data` | `0x403000–0x403388` | 904 |
| **`.rsrc`** | `0x404000–0x646e00` | **2.371.072** |
| `.reloc` | `0x647000–0x647c00` | 3.072 |
| `tdb` | `0xffdff000–0xffe00000` | 4.096 |

`procedure_count: 63` · `string_count: 108` · image base `0x400000`

**El 99,3 % del ejecutable son recursos; el código real ocupa 3.584 bytes.**

### Composición de los recursos (Evidencia `ev_105a59fe…`, cobertura complete)

| Tipo | Cantidad | Bytes |
|---|---:|---:|
| `RT_ICON` (3) | 80 | **2.363.520** |
| `RT_MENU` (6) | 1 | 48 |
| `RT_GROUP_ICON` (14) | 8 | 1.168 |
| `RT_VERSION` (16) | 1 | 716 |
| `RT_MANIFEST` (24) | 1 | 617 |

8 iconos pesan exactamente **270.376 bytes** = icono 256×256 a 32 bpp
(`262.144` XOR bitmap + `40` BITMAPINFOHEADER + `8.192` máscara AND).
**4 de ellos son byte-idénticos** (SHA-256 `27199406a8b0…` ×4) → payload
duplicado, y eso explica el tamaño del archivo.

### PDB recuperado

> `SafariLauncher.pdb` — GUID `138b14c6-9a84-45fc-9b42-1decb5127a16`,
> age (hex) 1, versión RSDS. Ghidra reporta *load state unknown*;
> REA no admite un PDB suministrado por el caller.

Confirma que el nombre interno del proyecto era **SafariLauncher**.

### Strings (Evidencia `ev_3a4fcaf29da79c56d125c171fb3458a0368c17912990c2e0337a285f3ba69010`)

Strings no-CRT relevantes:

```
0x402154  Apple Application Support
0x402188  PATH
0x4021c8  WEBKITNIGHTLY
0x4023d4  Safari.dll
0x4023ec  AppleVersions.dll
0x402410  CheckCompatibilityOfApplication
0x402430  _safariDLLMain@16
0x4021e8  "The version of Safari on your computer is no longer supported. …"
0x402300  "Your copy of Safari is missing important software resources. …"
0x4023ac  "Safari can't open."
0x646218  534.57.2
```

### Procedimientos (Evidencia `ev_e46ca90db85859bdf0a0df5e0415cf0c7cd3eb54685d9935d0006ce86960e800`)

63 en total. Solo **4 son lógica propia** (sin nombre porque no cargó el PDB);
el resto es CRT (`___tmainCRTStartup`, `__security_check_cookie`,
`__SEH_prolog4`, `__ValidateImageBase`…) e imports `EXTERNAL:*`.

| Dirección | Tamaño | Papel |
|---|---:|---|
| `FUN_00401000` | 0x90 | construye `<dir>\Apple Application Support` |
| `FUN_00401090` | 0x150 | prepende una ruta al `PATH` |
| `FUN_004011e0` | 0x60 | lee la variable de entorno `WEBKITNIGHTLY` |
| `FUN_00401240` | 0x1DD | **main** del lanzador |

### Pseudocódigo

En `inspect-safari/Safari.exe.pseudocodigo.c`. Flujo reconstruido:

```
entry @ 0x401733  [ev_52efa70b…]
  → ___security_init_cookie()
  → ___tmainCRTStartup()
      → FUN_00401240 (main)  [ev_bdd3d5d4…]
          1. HeapSetInformation(0, 1, 0, 0)            // vía GetProcAddress
          2. GetModuleFileNameW(NULL, path, 260)
          3. aas = FUN_00401000()   // <dir>\Apple Application Support
          4. si WEBKITNIGHTLY definida [ev_0325026f…]:
                 PATH = nightly ; aas ; PATH   (dos veces FUN_00401090)
             si no:
                 SetDllDirectoryW(aas)  si existe [ev_b8bb9e54… …]
                 PATH = aas ; PATH      como fallback
          5. AppleVersions.dll!CheckCompatibilityOfApplication(path, 0x390002, 0x50022)
             → 0 ⇒ MessageBox "…no longer supported…"
          6. Safari.dll!_safariDLLMain(a, b, c, d)     // UI real
```

**Evidencias de pseudocódigo:**

| Función | Evidencia |
|---|---|
| `entry` | `ev_52efa70b238fd58448aa7e31ec720a881d651335849733cd3faf7c3356f4b2ae` |
| `FUN_00401000` | `ev_7ca20504e4843841ef09024af633af72bea40cd06b57eee8a65f51812115209f` |
| `FUN_00401090` | `ev_b8bb9e54dc9f349f497481d631a672978fc2b2aaac22f3239e5f369a7e6aeb2f` |
| `FUN_004011e0` | `ev_0325026f330710e4d22ef4a21b0efe7f7e4b3bd905c798f8ea96e30d9dd3485b` |
| `FUN_00401240` | `ev_bdd3d5d49d5bb41144997b48781905cd63a7e0e3a3a1786bf431091361000722` |

Perfil de análisis Ghidra: digest `3de5374fadd78e0d56219c4afc6b4f2efac7101ff92b72faf375fb0070bbc896`.

---

## 7. Safari.dll — el navegador encontrado (Ghidra/MCP)

`Safari.dll` (8.319.336 B, SHA-256 `3fa1466f655bebca7df9bc9bb17ef45b7d982032fea8368be0d9fad2fb48b20c`)
es **el navegador**. Compilado 2012-04-25 16:49:38 UTC, image base `0x10000000`,
PDB `Safari.pdb` (GUID `f65c8a96-9acf-4a09-88d8-d25f65b4860e`).

### Overview (Evidencia `ev_af1a14e355bb91ea36697fb89fc28a9a900c4e68851b395a45aacecbe6597522`)

| Segmento | Rango | Tamaño |
|---|---|---:|
| `.text` | `0x10001000–0x10493000` | **4.792.320** |
| `.rdata` | `0x10493000–0x10529000` | 614.400 |
| `.data` | `0x10529000–0x10530ce4` | 31.972 |
| `.rsrc` | `0x10531000–0x107b7e00` | 2.649.600 |
| `.reloc` | `0x107b8000–0x107f3a00` | 244.224 |

`procedure_count: 13.229` · `string_count: 5.815` · 25 DLLs importadas · 44 exports
(incluido `_safariDLLMain@16`). Importa `CoreFoundation` (231), `USER32` (184),
`CoreGraphics` (136), `KERNEL32` (134), `JavaScriptCore` (92), `CFNetwork` (82),
`QuartzCore` (82), más los plugins internos `PubSubDLL`, `Search`,
`SpellChecker` y `SafariTheme`.

### Cadena de arranque del navegador

```
Safari.exe (lanzador)
  └─ GetProcAddress(Safari.dll, "_safariDLLMain@16")
       └─ safariDLLMain @ 0x10098020          [ev_04f4c19d…]  (despachador, 73 B)
            └─ FUN_10097040 = WinMain real    [ev_9207bde6…]
                 · SetCurrentProcessExplicitAppUserModelID("Apple.Safari")
                 · SetProcessDEPPolicy(1), OleInitialize, InitCommonControlsEx
                 · instancia única (CreateMutexW)
                 └─ FUN_1005f550 = run        [ev_f308bed0…]  (init + bucle)
                      └─ FUN_100b76b0 = launch [ev_5e49b78b…] (rect, URL inicial)
                           └─ FUN_100a8240 = crear ventana  [ev_5454ac0d…]
                                · fastMalloc(0x220) → ctor FUN_100a8500
                                └─ FUN_100a8320             [ev_03970b57…]
                                     · título localizado: WebLocalizedLPCTSTRUTF8("com.apple.Safari","Safari")
                                     · estilo 0x60F0000 (ventana superpuesta visible)
                                     · CreateAcceleratorTableW
                                     · icono alternativo si WEBKITNIGHTLY definida
                                     └─ FUN_100ba4c0 = **CreateWindowExW**  [ev_bd63f9ed…]
                                          (clase = átomo de FUN_1002c740 =
                                           helper ATL: GetClassInfoExW → RegisterClassExW)  [ev_f5940b1a…]
                                · ShowWindow + RedrawWindow
```

### Clases de ventana y mecanismo de instancia única

- Clase principal: **`SafariOverlappedWindow`** (string `0x104f20b4`);
  diálogos marcados con la propiedad **`SafariDialog`** (`0x104f1b6c`).
- `FUN_10096ef0` [ev_5f6184eb…]: si `FindWindowW(L"SafariOverlappedWindow")`
  encuentra una ventana existente, la **segunda instancia no arranca el
  navegador**: `OpenProcess(0x438)` → `VirtualAllocEx` + `WriteProcessMemory`
  (copia el argumento/URL al proceso vivo) → `SetForegroundWindow` →
  `SendMessageW(hWnd, 0x8012 /*WM_APP+0x12*/, 0, ptr)` y `return 0`.
- `FUN_100a8c40` [ev_0b54cbfc…]: filtro del bucle de mensajes —
  `GetPropW(hwnd, "SafariDialog")` + `IsDialogMessageW`.

### Flags internos de arranque (prefs, leídos por el WinMain)

`snapshotFetcher`, `reinstall`, `hideicons`, `showicons`, `console`,
`enableInternalDebugMenu`, `disableInternalDebugMenu`, `printLaunchTime`,
`quitAfterLaunch`, `newProcess`.

### Otros strings significativos (Evidencia `ev_8fe6c59fde9003caf6e3e186a3c7074e722ac1cbb02002feecf499bf993c8182`)

```
0x104ef78c  Safari: ConnectionScheduler
0x104f0a08  SafariGeolocationEnabled
0x104f0b74  \com.apple.Safari.plist
0x104f2208  //./pipe/com.apple.SafariSnapshotHelper.I
0x104f2260  //./pipe/com.apple.SafariSnapshotHelper.O
0x104f22b4  SafariSnapshotHelper -snapshotFetcher "%@"
0x104f23a0  com.apple.Safari.SnapshotFetcher
```

> Safari 5.1 ya incluía el helper de **capturas de página** vía named pipes
> (el origen de la futura función "Save As Snapshot"), y preferencias de
> **geolocalización**.

---

## 8. Conclusiones

1. **`Safari.exe` no es el navegador: es un lanzador** de 3.584 bytes de código
   (proyecto interno *SafariLauncher*). La UI real vive en `Safari.dll`.
2. Su única labor: **exponer `Apple Application Support` al buscador de DLL**
   (`SetDllDirectoryW` o prepend al `PATH`), comprobar compatibilidad con
   `AppleVersions.dll` y cargar `Safari.dll!_safariDLLMain`.
3. **`Safari.dll` (4,6 MB de código, 13.229 procedimientos) es el navegador**:
   WinMain propio, ventana principal de clase `SafariOverlappedWindow` creada
   con `CreateWindowExW`, título localizado "Safari" y bucle de mensajes con
   soporte de diálogos (`SafariDialog`).
4. **Instancia única por ventana + IPC directo**: una segunda copia localiza la
   ventana existente, le inyecta la URL con `WriteProcessMemory` y se cierra.
5. El **99,3 %** del peso de `Safari.exe` son iconos (2,36 MB), con 4 de ellos
   duplicados.
6. Soporta la variable de entorno **`WEBKITNIGHTLY`** para apuntar a un build
   alternativo de WebKit — característica interna de desarrollo (en
   `Safari.dll` también sirve para sustituir el icono por el de `webkit.exe`).
7. **No se detectó código malicioso**: la sección `.unwante` es una tabla de
   trampolines legítima de WebKit/JSC; el `WriteProcessMemory` de
   `FUN_10096ef0` es el mecanismo estándar de apertura remota de URL entre
   instancias del mismo producto.

---

## 9. Estado de las herramientas

| Provider REA | Estado |
|---|---|
| **ghidra** | ✅ **12.1.4 disponible** (`GHIDRA_INSTALL_DIR` definido) |
| hopper | ❌ solo macOS (`unsupported_host` en win32) |
| ida | ❌ `REA_IDA_MCP_CONFIG` sin definir |
| kuna | ❌ `REA_KUNA_COMMAND` sin definir y no admite PE |

Java: **JDK 21.0.12 (64-bit)** — `C:\Program Files\Java\jdk-21.0.12`

### Cambios de configuración realizados

| Cambio | Ruta / valor |
|---|---|
| Ghidra 12.1.4 extraído | `C:\Users\punks\tools\ghidra_12.1.4_PUBLIC\` |
| Variable de entorno de usuario | `GHIDRA_INSTALL_DIR` |
| Clave `environment` en la registración MCP | `C:\Users\punks\.config\opencode\opencode.json` |
| `GHIDRA_HEADLESS_MAXMEM` | `8G` (evita OOM con binarios grandes) |
| `REA_GHIDRA_DISABLED_ANALYZERS` | `x86 Constant Reference Analyzer` |
| `REA_GHIDRA_STARTUP_TIMEOUT_MS` | `900000` |
| `mcp.timeout` | arranque `600000` / ejecución `1800000` |
| Respaldo de la configuración | `opencode.json.bak-ghidra` |

> La clave correcta en la registración MCP es **`environment`**; `env` se
> ignora silenciosamente. OpenCode **recarga automáticamente** el servidor MCP
> al editar la configuración (verificable con el `started_at` del servidor).

### Pendiente

- [x] Acceso MCP de REA + Ghidra operativo
- [x] Analizar `Safari.dll` con Ghidra (13.229 procedimientos)
- [x] Descompilar `Safari.dll!_safariDLLMain@16` y seguir la cadena hasta la
      ventana del navegador
- [ ] Resolver el significado de `0x390002` y `0x50022` en
      `CheckCompatibilityOfApplication` (probablemente una versión
      compuesta `0x39.0.2` / `0x50.0.22` de AppleApplicationSupport)

---

## 10. Limitaciones y avisos

- El pseudocódigo de las secciones 6 y 7 **sí** procede de REA/Ghidra y lleva
  sus Evidencias; las secciones 3–5 proceden de un parser PE propio y no las
  tienen.
- **No se ejecutó ningún binario**: todo es análisis estático.
- Los nombres `FUN_xxxxxx` indican que el PDB **no se cargó** (`SafariLauncher.pdb`
  en `Safari.exe` y `Safari.pdb` en `Safari.dll`): no hay nombres ni tipos
  originales. Varios bucles de Windows (p. ej. el cuerpo de `FUN_100a8c40`)
  quedan con variables artificiales (`in_ECX`) por convenciones stdcall.
- La semántica de los argumentos de `_safariDLLMain@16` (los 4 que reenvía el
  lanzador) no está establecida.
- `Search.dll` y `PubSubDLL.dll` **ya estan en el clon** (clonados en la fase
  de notas para Habitat); siguen fuera:
  `SpellChecker.dll`, `SafariTheme.dll`,
  `AppleVersions.dll` y el resto de `Apple Application Support` **siguen sin
  estar en el clon** (se añadió `Safari.dll` a la opción B).
- La instalación original en `C:\Program Files (x86)\Safari` no se ha modificado.

---

## 11. Notas para el clon «Habitat» (Vala + WebKitGTK)

Posteriormente a este informe se preparó un clon en Vala llamado **Habitat**
que usará **WebKitGTK** en Linux. Por decisión del usuario se ignoró toda la
Capa 2 (WebKit, CoreFoundation, dependencias de Apple) y se concentró el
trabajo en la capa de datos y UI de Safari. El resultado está en
**`HABITAT.md`**, con:

- Esquema completo de `Bookmarks.plist`, `History.plist`, `TopSites.plist` y
  `ReadingList.plist` (sobre un perfil real de usuario, solo lectura),
  más las funciones y claves de `Safari.dll` que los leen/escriben
  (Evidencias REA incluidas).
- Análisis de `Defaults.plist` (87 claves), `UserAgents.plist`,
  `Reader.html` (estructura completa; el JS de los handlers **no existe en
  ningún fichero** — lo aporta código nativo) y de los 42 paneles HTML de
  `Safari.resources`. TopSites no tiene HTML: es UI nativa con URL
  interna `topsites://`.
- Lógica de alto nivel de `Search.dll` (motor de índice tipo Spotlight:
  normaliza a minúsculas, tokeniza, puntúa con peso 1.0) y de `PubSubDLL.dll`
  (detección `http`/`feeds:`, parseo con libxml2 streaming + libtidy,
  esquema SQLite de RSS completo, refresco 30 min / expiración 14 días).

Entregables nuevos: `HABITAT.md`, carpeta `habitat-assets\` (recursos y
plists copiados; los originales intactos) y los clonados `Search.dll` y
`PubSubDLL.dll` en `inspect-safari\`.
