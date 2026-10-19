# Habitat — notas de diseño extraídas de Safari 5.1.7 (Windows)

Objetivo: clon en **Vala + WebKitGTK (Linux)** llamado *Habitat*. Este documento
recoge, solo de la capa que interesa (UI, datos y lógica de aplicaci\u00f3n; se
omite toda la capa WebKit/CoreFoundation de Apple):

1. Estructuras de datos de **historial y marcadores** (en `Safari.dll` y en el perfil real).
2. An\u00e1lisis de **`Defaults.plist`**, **`UserAgents.plist`**, **`Reader.html`** y **TopSites**.
3. L\u00f3gica de alto nivel de **`Search.dll`** (consultas) y **`PubSubDLL.dll`** (RSS).

Fuentes: binarios clonados en `inspect-safari\`, recursos en `habitat-assets\`
(copiados; originales solo-lectura) y un **perfil real** de Safari en
`%APPDATA%\Apple Computer\Safari` (le\u00eddo, nunca modificado). Las Evidencias REA
(`ev_…`) son salidas de Ghidra v\u00eda REA; las marcas *(grep local)* son
b\u00fasquedas literales sobre los bytes, sin Evidencia REA.

---

## 1. Historial y marcadores

### 1.1 D\u00f3nde y c\u00f3mo se guardan (terreno, no hip\u00f3tesis)

Safari 5.1 en Windows **no usa SQLite** para marcadores/historial: guarda
**plists binarios** (`bplist00`) en `%APPDATA%\Apple Computer\Safari\`:

| Fichero | Tama\u00f1o (perfil real) | Contenido |
|---|---|---|
| `Bookmarks.plist` | 2.936 B | \u00e1rbol de marcadores |
| `History.plist` | 242 B | historial por URL |
| `TopSites.plist` | 807 B | cuadr\u00edcula Top Sites |
| `ReadingList.plist` | 236 B | lista de lectura |
| `LastSession.plist` | 1.000 B | sesi\u00f3n a restaurar |

Todos est\u00e1n copiados en `habitat-assets\` (el binario se vuelca con
`python -m plistlib` o `plutil`).

### 1.2 Esquema de `Bookmarks.plist` (observado en el perfil + strings de Safari.dll)

\u00c1rbol de diccionarios; cada nodo tiene exactamente estas claves:

```
RA\u00cdZ / CARPETA (WebBookmarkTypeList):
  Children                : [nodo, nodo, …]
  Title                   : "Noticias" | "Populares" | "Favoritos IE importados" | …
  WebBookmarkType         : "WebBookmarkTypeList"
  WebBookmarkUUID         : "GUID en may\u00fasculas, p. ej. 0C638567-D260-40B5-B1E6-ACD1D82FCAFA"
  WebBookmarkFileVersion  : (solo ra\u00edz)

HOJA (WebBookmarkTypeLeaf):
  URLString               : "http://www.apple.com/es/"
  URIDictionary           : { title: "Apple" }     ← dict anidado
  WebBookmarkType         : "WebBookmarkTypeLeaf"
  WebBookmarkUUID         : "GUID"
```

Carpeta especiales recognizibles por `Title`/UUID: **BookmarksBar** y
**BookmarksMenu** (\u00e1mbos aparecen 4\u00d7 en `Safari.dll`, *grep local*). El
perfil trae por defecto ~15 hojas (Apple, Yahoo, Google Maps, YouTube,
Wikipedia, CNN en Espa\u00f3l, El Pa\u00eds, El Mundo, ABC, BBC…).

Los **tres tipos** est\u00e1n como CFString en `Safari.dll`
(b\u00fasqueda `WebBookmark`, Evidencia `ev_8e6b5b7094bec10fbab932d9bc3fba7aec0ec6e4b7fef31e0d6fa71c9478e06d`):

| Valor | Direcci\u00f3n |
|---|---|
| `WebBookmarkType` | `0x104fec48` |
| `WebBookmarkTypeLeaf` | `0x104fec58` |
| `WebBookmarkTypeList` | `0x104fec6c` |
| `WebBookmarkTypeProxy` | `0x104fec80` (nodo «proxy», p. ej. feeds/carpetas smart) |

Claves observadas tambi\u00e9n en binario (Evidencia `ev_b283d9b5a56dd6c28f1626a256245fa92ac9bc6f6d81f18f310e36744d25fe04`):
`URLString` (`0x104f0004`, `0x105007dc`), `Title` (`0x104fe96c`, `0x10501ca8`),
`URIDictionary` (`0x105007cc`).

### 1.3 Esquema de `History.plist`

```
{
  WebHistoryFileVersion : 1,
  WebHistoryDates : {
      "<URL>" : {
          title          : "T\u00edtulo de la p\u00e1gina",
          lastVisitedDate: 814053320.7,   ← segundos desde 2001-01-01 (epoch Cocoa),
          visitCount     : 3,
          redirectURLs   : [ "<URL anterior>", … ]
      }, …
  }
}
```

Claves confirmadas en `Safari.dll` (Evidencia `ev_b283d9b5…` arriba):
`lastVisitedDate` `0x10513370`, `visitCount` `0x10513380`,
`redirectURLs` `0x105133c8`. La clave `WebHistoryDates` (`0x105131d4`) se usa en
dos funciones (`FUN_10233a90`, `FUN_102398b0` — xrefs Evidencia
`ev_4c3f9bc4c2b247a7b533641f398b617420b50747d28c51892c31dec90bb75cab`), es decir:
**una escritura/lectura de historial y una recarga/serializaci\u00f3n**.

### 1.4 Esquema de `TopSites.plist` y `ReadingList.plist`

```
TopSites.plist:
{
  TopSites : [ { TopSiteURLString, TopSiteIsBuiltIn (bool), TopSiteTitle }, … ],
  BannedURLStrings : [ … ],          ← URLs vetadas («no volver a sugerir»)
  DisplayedSitesLastModified : fecha
}
ReadingList.plist:   ← MISMOS campos que Bookmarks (ra\u00edz WebBookmarkTypeList)
{
  WebBookmarkFileVersion, ShouldOmitFromUI,
  Title : "com.apple.ReadingList",
  WebBookmarkType : "WebBookmarkTypeList", WebBookmarkUUID : "…"
}
```

Funciones propietarias (xrefs REA):

- `TopSites.plist` → `FUN_100c6220` (Evidencia `ev_1c466508c17c11af3f384cf81c55278b66da9e17b5b034940e1cf6fe0191bc53`).
- `ReadingList.plist` → `FUN_101005e0` (Evidencia `ev_41cbb9489bce7f05d7976af183f20983713535d4395f3ff3ab7f8d066ba76b64`).
- `Bookmarks.plist` → `FUN_10108670` (Evidencia `ev_3cf2841af1db513c87f511bf7a0530ab51760a9865ebd6e47defcf02c539b67d`):
  singleton de 245 B que construye la CFURL del fichero — `fastMalloc(4)` +
  `__CFStringMakeConstantString("Bookmarks.plist")` + `CFRetain`, cacheado en
  `DAT_10530438` (se crea una vez y se reutiliza siempre).

### 1.5 C\u00f3mo organiza `Safari.dll` las claves (patr\u00f3n a copiar)

**Cada clave de plist es una CFString constante cacheada individualmente.**
Ejemplo, la clave `URIDictionary`, `FUN_10106490` (90 B, Evidencia
`ev_34ea706e1b52c95a6888683a3d6cde52f0f0db5995add6deb56b6c8d735acdc7`):

```c
if ((_DAT_1052e580 & 1) != 0) return _DAT_1052e57c;      // ya cacheada
piVar1 = WTF::fastMalloc(4);
iVar2 = __CFStringMakeConstantString("URIDictionary");
*piVar1 = iVar2; if (iVar2) CFRetain(iVar2);
_DAT_1052e57c = piVar1;                                   // se cachea en .data
```

Mismo molde para el path `Bookmarks.plist` (§1.4). Traducci\u00f3n a Vala: un
`static once` por clave o simplemente constantes `const string`.

### 1.6 Eventos en memoria (se\u00f1ales → GObject)

`Safari.dll` publica notificaciones con estos nombres exactos (Evidencia
`ev_8e6b5b70…`, direcciones `0x104efe38`–`0x104f00…`):

```
WebBookmarksWereReloadedNotification     WebBookmarkDidChangeNotification
WebBookmarkWillChangeNotification        WebBookmarksWillBeRemovedNotification
WebBookmarksAddedNotification            WebBookmarkUnreadCountChanged
WebBookmarksWereRemovedNotification
```

En Habitat: se\u00f1ales GObject con el mismo vocabulario (facilita seguir
tutoriales/documentaci\u00f3n de Safari al letter).

### 1.7 URL interna de Top Sites (grep local, sin Evidencia REA)

En `Safari.dll` aparecen juntos, en este orden:
`…shotFetchingStatusChanged … topsites … topsites:// … topsites: … TopSites.plist … apple.com … Safari: TopSites …`
\u2192 el esquema interno es **`topsites://`** y el t\u00edtulo de la ventana
**«Safari: TopSites»**. Existe adem\u00e1s `safari-resource:/ReadingList.html`
(1\u00d7 en `Safari.dll`) y el fichero `Safari.resources\ReadingList.html`
existe de verdad.

> **TopSites no tiene HTML**: es UI **nativa** (cuadr\u00edcula dibujada por
> `Safari.dll`) alimentada por `TopSites.plist`. En Habitat: widget GTK
> propio + `decide-policy` para interceptar `topsites://`.

---

## 2. Recursos de UI

### 2.1 `Defaults.plist` (4.190 B, 87 claves — copiado en `habitat-assets\`)

Plist XML con los **defaults de f\u00e1brica** de Safari. Grupos relevantes:

- **L\u00edmites de datos**: `BackForwardListSizeLimit 200`,
  `BackForwardMenuSizeLimit 30`, `HistoryAgeInDaysLimit 31`,
  `HistoryDaysMenuItemsLimit 7`, `RecentHistoryMenuItemsLimit 18`,
  `MaxTabsToOpenWithoutConfirmation 50`, `DefaultDatabaseQuota 5242880`,
  `URLMenuItemTitleMaxWidth 400`.
- **Marcadores y RSS**: `RSSBookmarksInBarAreSubscribed true`,
  `BookmarkFeedsInSafari true`, `BookmarkFeedsInMail false`,
  `BookmarksMenuIncludesBookmarksToolbar true`,
  `BookmarksMenuIncludesAddressBook/Rendezvous false`,
  `BookmarksSearchFieldScope 1`, `BookmarksCollectionsInclude* true`.
- **UI**: `ShowFavoritesBar true`, `ShowLocationBar true`, `ShowStatusBar false`,
  `SidebarSplitViewDividerPosition 300`, `TopSitesGridArrangement 1`,
  `ConfirmClosingMultiplePages true`, `CommandClickMakesTabs true`,
  `HeaderFooterFontSize 7`, `PrintHeadersAndFooters true`.
- **Relleno/autocompletar**: `AutoFillFromAddressBook true`,
  `AutoFillMiscellaneousForms true`, `AutoFillPasswords false`,
  `AskBeforeSubmittingInsecureForms true`.
- **Seguridad**: `WarnAboutFraudulentWebsites true`.
- **WebKit**: `WebKitCacheModelPreferenceKey 2`, `WebKitDNSPrefetchingEnabled`,
  `WebKitFullScreenEnabled`, `WebKitOfflineWebApplicationCacheEnabled`,
  `WebKitEditableLinkBehavior 4`, `WebKitTextAreasAreResizable`,
  `WebContinuousSpellCheckingEnabled`, `WebIconDatabaseEnabled`,
  `WebKitJavaScriptCanOpenWindowsAutomatically false`, etc.
  **Detalle importante**: casi todas las claves WebKit aparecen **dos veces** —
  una normal y otra con prefijo
  `com.apple.Safari.ContentPageGroupIdentifier.WebKit2…` (la variante que aplica
  al **proceso contenido** de WebKit2). Habitat con WebKitGTK solo necesita la
  variante simple.
- **Debug/reset**: `DebugCachePageText`, `ResetSafariOptionsMask -1`,
  `RunawayJavaScriptTimerEnabled`, `StartFlashAutomatically`.

> En Habitat: mismo esquema de nombres de clave en **GSettings/dconf** o en un
> plist propio \u2014 facilita importar cualquier ajuste documentado de Safari.

### 2.2 `UserAgents.plist` (4.078 B — copiado en `habitat-assets\`)

`<array>` de `<dict>` con claves:

```
name | version | platform | user-agent | show-platform (opcional) | separator:true (fila vac\u00eda de men\u00fa)
```

Contenido exacto (men\u00fa de agencias del men\u00fa «Agente de usuario»):

| name | version | platform | UA (resumen) |
|---|---|---|---|
| Safari | 5.1.6 | Mac | `…Macintosh… 10_6_8 … AppleWebKit/534.57.2 … Version/5.1.6 Safari/534.57.2` |
| Safari | 5.1.6 | Windows | `…Windows NT 6.1 … AppleWebKit/534.57.2 …` |
| Safari iOS | 4.3.3 | iPhone / iPod touch / iPad | `…CPU iPhone OS 4_3_3 … Mobile/8J2 Safari/6533.18.5` |
| Internet Explorer | 9.0 / 8.0 / 7.0 | Windows (`show-platform: false`) | `…MSIE 9.0…` / `…Trident/4.0` |
| Firefox | 4.0.1 | Mac / Windows | `…Gecko/20100101 Firefox/4.0.1` |
| Opera | 11.11 | Mac / Windows | `…Presto/2.8.131 Version/11.11` |

Separadores (`separator:true`) entre grupos. Habitat: copiar el formato y
rellenar con UA modernos; el UA real de Habitat ser\u00e1 el de WebKitGTK.

### 2.3 `Reader.html` (650 l\u00edneas, 18.238 B — copiado en `habitat-assets\`)

**Arquitectura**: plantilla HTML + CSS; **el JS de los handlers NO se
entrega como fichero** (ver abajo). Estructura:

1. `<style id="article-content">` — tipograf\u00eda de art\u00edculo (Palatino/Georgia,
   `h1.title`, `.page.rtl`, `#article pre-wrap`, `img` flotados, `@media print`
   oculta `.original-url`). Aqu\u00ed vive la **paginaci\u00f3n del art\u00edculo**.
2. `<style id="reader-ui">` — capa de UI:
   - `#background`: overlay fijo `rgba(0,0,0,0.8)` (clic = cerrar Reader).
   - `#container`: 862 px centrado (`left:50%; margin-left:-431px`),
     `pointer-events:none`; `#centered` `#article` con scroll propio.
   - Transiciones `body.preloading` ( Reader entra desliz\u00e1ndose: `translate3d(0,100%,0)` \u2192 0, overlay con `opacity` ).
   - HUD (`#hud`, role=toolbar): botones `#hud-zoom-out/in/mail/print/exit`,
     con im\u00e1genes `safari-resource:/ReaderHUD*(@2x).png` y estados `:active`.
   - Sombras/scrollbars con `-webkit-border-image` (`ReaderDropShadow`,
     `ReaderTrack`, `ReaderThumb`).
3. `<script src="safari-resource:/localizedStrings.js">` — \u00fanico `<script>`.
4. `<body class="preloading" onload="ReaderJS.loaded();"
   onselectstart/onmouseup="setHUDAcceptsPointerEvents(…)"
   onblur="didLoseFocus();">` con:

```html
<div id="background" onclick="deactivateAfterAnimation();"></div>
<iframe id="next-page-container"></iframe>   <!-- p\u00e1gina siguiente del art\u00edculo partido -->
<div id="container">
  <div id="resize-indicator"></div>
  <div id="centered">
    <div id="drop-shadow"></div>
    <div id="article" onscroll="articleScrolled();" tabindex="0">
      <div id="hud" role="toolbar" onmouseover/onmouseout="hudMouseOver/hudMouseOut">
        <button id="hud-zoom-out" onclick="makeTextSmaller();"></button>
        <button id="hud-zoom-in"  onclick="makeTextLarger();"></button>
        <button id="hud-mail"     onclick="mailArticle();"></button>
        <button id="hud-print"    onclick="printArticle();"></button>
        <button id="hud-exit"     onclick="deactivateAfterAnimation();"></button>
        <div id="fade-top" class="article-fade"></div>
        <div id="fade-bottom" class="article-fade"></div>
```

**Hallazgo clave — el JS de control no existe en ning\u00fan fichero:**
b\u00fasqueda de `makeTextSmaller` (ASCII y UTF-16) en los 6 binarios clonados +
`Search.dll`/`PubSubDLL.dll`/`SafariTheme.dll` + **todos** los ficheros de la
instalaci\u00f3n < 5 MB + binarios \u2265 5 MB (`WebKit2WebProcess.exe`, AAS…):
**\u00fanico hito = el propio `Reader.html`**. En `Safari.dll` s\u00ed est\u00e1 el s\u00edmbolo
`ReaderJS` junto a `preparePrintingMailingFrame` (grep local) \u2192 las funciones
las aporta **c\u00f3digo nativo en tiempo de ejecuci\u00f3n** (bindings de WebKit
«ScriptObject»), no un `.js` de recursos.

> **Para Habitat**: reutilizar `Reader.html` casi literal (es HTML/CSS puro y
> WebKitGTK soporta `-webkit-*`), pero hay que **escribir el JS**:
> `ReaderJS.loaded`, `articleScrolled`, `hudMouseOver/Out`,
> `setHUDAcceptsPointerEvents`, `makeTextSmaller/Larger`, `mailArticle`,
> `printArticle`, `deactivateAfterAnimation`, `didLoseFocus` \u2014 ninguno trae
> implementaci\u00f3n. El art\u00edculo se inyecta en `#article` y la p\u00e1gina+1 en el
> iframe `#next-page-container`.

### 2.4 Paneles HTML restantes

`Safari.resources` contiene **42 paneles HTML** (Preferences*, dialogs,
`FindBanner.html`, `ExtensionsView.html`, `ReadingList.html`, …) que Safari
carga como UI de ventanas/di\u00e1logos v\u00eda `safari-resource:/…`. Mismo patr\u00f3n
que Reader: **UI declarativa HTML/CSS + controlador nativo**. Habitat puede
seguirlo (GTK + `WebKitWebView` embebido por panel) o migrar a GTK puro.

---

## 3. `Search.dll` — c\u00f3mo arma las consultas

**Ficha**: 344.424 B, PE32/x86, compilado 2012-04-25, image base
`0x10000000`, **15 exports C++** y solo importa `KERNEL32` + `MSVCP80/MSVCR80`
\u2192 **motor de \u00edndice de texto autocontenido** (herencia de Spotlight portado a
Windows; «SW» = *Search for Windows*).

### 3.1 API (los 15 exports)

```
Índice:   SWOpenIndexWriter(ruta)   SWOpenIndexReader(ruta)
          SWCloseIndex  SWClearIndex  SWIsDatabaseCorrupted
Indexado: SWBeginAddDocumentToIndex(índice, idDoc) → __SWDocument*
          SWAddDataToDocument(doc, campo, texto)    ← añade texto por campo
          SWGetDataFromDocument(doc, campo)
          SWEndAddDocumentToIndex  SWCloseDocument
          SWRemoveDocumentFromIndex
Búsqueda: SWSearch(índice, cadena1, cadena2) → __SWSearchResult*
          SWGetSearchResultCount(r)  SWGetSearchResultAtIndex(r, idx)
          SWEndSearch(r)
```

`__SWSearchResult` mide **16 bytes** (`{+0, +4, +8, +0xc = motor}`).

### 3.2 Flujo de la consulta (REA/Ghidra)

**`SWSearch`** — Evidencia `ev_8a91f8b85811d07b6761ee4e33a2db0cda2dfc0a72c8fb25c72dfc1623cafa29`
(entry `0x10001c90`, 189 B): si el motor ya est\u00e1 inicializado devuelve `NULL`;
crea el resultado con `operator_new(0x10)` y delega en
`FUN_10001280(resultado+0xc, índice, cadena1, cadena2, &+4, &+8)`.

**`FUN_10001280`** — el motor — Evidencia `ev_c81e87d0977a2b68559b92280ac4e41fd67d3d7621d08c041b23262890199a3b`
(entry `0x10001280`, 325 B):

```c
*param_4 = 0; *param_5 = 0; *(int*)this = 0;
if (param_3 == NULL) return 0;
_Memory = _wcsdup(param_3);              // ← param_3 = texto de búsqueda
// recorre carácter a carácter con FUN_1000e440 → NORMALIZA A MINÚSCULAS
…
obj73b0 = FUN_100073b0(normalizado);     // tokenizador (obj de 0x10 B)  → *param_4
objScore = new 0x18; objScore->vtable = PTR_FUN_10039504;
objScore->peso = 1.0;                    // 0x3FF0000000000000 (double)
*param_5 = objScore;
FUN_10001000(*param_4, objScore);        // engancha el score al tokenizador
FUN_100013f6();                          // ejecuta la búsqueda
// param_2 (cadena1) pasa por FUN_100044d0 → objeto 0x20 B = filtro/ámbito
```

### 3.3 Lectura en lenguaje llano

La l\u00f3gica de consulta es **sorprendentemente simple**:

1. **Normaliza** la cadena a min\u00fasculas (car\u00e1cter a car\u00e1cter, `_wcsdup` + casefold).
2. **Tokeniza** en t\u00e9rminos.
3. Cada t\u00e9rmino recibe un *scorer* con **peso fijo 1.0** (vtable propia) \u2014
   es decir, **coincidencia simple ordenada**, sin TF-IDF configurable ni
   operadores booleanos visibles en esta capa.
4. El **segundo argumento** de `SWSearch` es un **filtro/\u00e1mbito** (objeto 0x20 B):
   en Safari distingue buscar solo en marcadores, en historial, etc.

**Decisi\u00f3n para Habitat**: no vale la pena reimplementar el \u00edndice. Usar
**SQLite FTS5** (`bm25()` da ranking real) detr\u00e1s de una API con la misma
forma: `openReader/openWriter`, `begin/endAddDocument`, `addData(doc, campo,
texto)`, `search(índice, query, filtro) → resultado{count, at(i)}`. Se
conserva el vocabulario de la API original.

---

## 4. `PubSubDLL.dll` — c\u00f3mo parsea RSS/Atom

**Ficha**: 542.568 B, PE32/x86, 37 exports `PSDLL_*`. Imports:
`CoreFoundation` 168, `CFNetwork` 59, **`libxml2` 48**, `libtidy`,
`JavaScriptCore` 21, `WebKit` (DOM), `libdispatch`, `USER32`.

### 4.1 Detecci\u00f3n de feeds

**`PSDLL_IsFeedURL`` — Evidencia `ev_8a9c70758218bf3983f14cbc4f44e20f671bfd88ef8b08bd632e2586a4098fbc`
(entry `0x1000108f`, 5 B):

```c
if (FUN_10005965(url)) return 1;   // esquema == "http"  (ev_f9a675168ef574662c8ca928573c8580f9d4e03c633a58f362a96feb461f03c5)
if (FUN_100059a8(url)) return 1;   // esquema == "feeds" (ev_b2e389af29a23aaa0ae199f0b6401b1b48795b146952de7b8ac27b986444f7bd, string "feeds" @0x100573b0)
return 0;
```

Ambas ramas: `CFURLCopyScheme` + comparaci\u00f3n. Adem\u00e1s existen las variantes
`feeds:%@` (`0x1005744c`) y errores de utilidad
`FeedURLUtilsCore: Couldn't parse feed URL <%@>` / `Multiple UUIDs in <%@>` /
`Multiple filters in <%@>` \u2192 soporte de URLs de feed **agregadas con UUID y
filtros** (`urlsFromAggregateFeedURL@FeedURLUtilsCore@PubSub@@…`).

### 4.2 Obtenci\u00f3n y parseo

- **`PSDLL_FeedURLCreateFromDOM(DOMDocument*, CFAllocator*)`**: convierte el
  **DOM de WebKit** de la p\u00e1gina en la URL del feed (la p\u00e1gina declara su
  feed v\u00eda `<link rel="alternate" type="application/rss+xml">`).
- `PSDLL_FeedEntriesCreateFromDOM` / `PSDLL_FeedLinksCreateFromDOM`: extraen
  entradas/enlaces del DOM.
- Parseo XML con **libxml2 en modo streaming**:
  `xmlTextReaderSetParserProp`, `xmlParseCharEncoding` (Evidencia
  `ev_1b33ac8003fecf21f2db16f6864c0a18981472515ee0b5ae6d0f64c5d0f1a2d0`)
  y **tolerancia a HTML sucio** con `htmlCreateMemoryParserCtxt` +
  `htmlParseDocument` + `tidyParseBuffer` (libtidy) para feeds mal formados.

### 4.3 Almacenamiento: SQLite (esquema completo recuperado)

Base real copiada en `habitat-assets\PubSub-Database.sqlite3` (37.888 B);
esquema extra\u00eddo de `sqlite_master`:

```sql
CREATE TABLE Clients (rowID PK, signature text unique not null, private integer, dateUsed real);
CREATE TABLE Feeds   (rowID PK, identifier text unique, id, title, subtitle, rights,
                      minUpdateInterval real default 0.0, dateUpdated real, timeZoneUpdated blob,
                      url text unique not null, alternateUrl, iconUrl, logoUrl,
                      lastErrorDomain integer, lastErrorCode integer, redirectedUrl,
                      localDateUpdated real, refreshLocalDate real,
                      refreshHttpDate text, refreshEtag text, refreshDataHash,
                      login, publishingProtocol, rebuildXml, feedFormat,
                      bonjourGuid, recoverOldEntries, foafUrl,
                      localDateCreatedOfNewestEntry);
CREATE TABLE Subscriptions (rowID PK, client integer references Clients not null,
                      feed integer references Feeds, refreshInterval real,
                      expirationInterval real, expirationDate real,
                      refreshesInBackground integer, downloadsEnclosures integer,
                      maxEnclosureSize real, enclosureTypesString text, unreadCount integer);
CREATE TABLE Entries  (rowID PK, identifier text unique, id, title, rights,
                      content integer references Contents, contentHash,
                      summary integer references Contents, summaryHash,
                      xmlRepresentation integer references Contents, xmlRepresentationHash,
                      dateUpdated real, timeZoneUpdated blob,
                      datePublished real, timeZonePublished blob,
                      dateCreated real, timeZoneCreated blob,
                      baseUrl, alternateUrl, author integer references Authors,
                      feed integer references Feeds …);
CREATE TABLE Contents (rowID PK, data blob, mimeType text);
CREATE TABLE Authors  (rowID PK, name, email, url, addressBookUid);
CREATE TABLE Enclosures (rowID PK, entry integer references Entries, url text not null,
                      mimeType, length integer, title,
                      downloadAuditStatus integer, downloadState integer,
                      downloadedPath, downloadErrorDomain integer, downloadErrorCode integer);
CREATE INDEX Subscriptions_nonbackground
       ON Subscriptions(client, refreshesInBackground, refreshInterval);
-- trigger:
CREATE TRIGGER Entries_update_feeds_localdatecreatedofnewestentryinfeed_after_insert
  AFTER INSERT ON Feeds … BEGIN UPDATE Feeds SET localDateCreatedOfNewestEntry =
  MAX(localDateCreatedOfNewestEntry, NEW.localDateCreated) WHERE rowID = NEW.feed; END;
```

### 4.4 SQL de aplicaci\u00f3n (strings en `PubSubDLL.dll`, Evidencia `ev_f1745f835b17f40e2b74bfbdc025989f6226abf32f80816f4dcdb215d54bb9c4`)

```sql
-- listado de entradas de un feed con fecha de exhibici\u00f3n saneada:
select e.*, coalesce(nullif(datePublished,0.0), nullif(e.dateUpdated,0.0),
       localDateCreated) as dateForDisplay
from Entries as e where e.feed=%llu;

-- expiraci\u00f3n por feed (lo que m\u00e1s vence primero por suscripci\u00f3n):
create temporary table ExpiredEntries as
  select rowID as entry, content, summary, xmlRepresentation, identifier, Entries.feed as feed
  from (select Feeds.rowID as feed, min(Subscriptions.expirationDate) as expirationDate
        from Feeds, Subscriptions where Subscriptions.feed=Feeds.rowID group by Feeds.rowID) as Exps,
        Entries
  where Entries.feed=Exps.feed and localDateCreated < expirationDate
    and current=0 and flagged=0;

-- idempotencia de suscripci\u00f3n:
select rowID from Subscriptions where feed=? and client=? limit 1;
select rowID from Subscriptions where feed in (select rowID from Feeds where url=?) and client=? limit 1;

-- limpieza de feeds fantasma:
delete from Entries where feed=0 and localDateCreated<%.0lf;
```

Acciones del ciclo de vida (strings): `AddFeedAction "%@” fired!`,
`RemoveFeedAction`, `CreateHomePageURLFromFeedURLAction`,
`CreateEntriesArrayForFeedAction`, `SetFeedRefreshIntervalAction %.1f`,
`GetFeedRefreshIntervalAction`; dominio **`com.apple.Safari.RSS`**;
`SafariGlue delegate feed "%@” unreadCount %d`.

### 4.5 Pol\u00edticas de refresco (perfil real, `PubSub\Clients.plist` + `Subscriptions`)

| Par\u00e1metro | Valor | Significado |
|---|---|---|
| `RefreshInterval` | `1800` | refresco cada **30 min** |
| `ExpirationInterval` | `1209600` | entradas caducan a los **14 d\u00edas** |
| `MaxEnclosureSize` | `8388608` | adjuntos m\u00e1x. **8 MB** |
| `RefreshesInBackground` | true | refresco sin ventana (indexado por `(client, refreshesInBackground, refreshInterval)`) |
| `Signature` | `com.apple.Safari` | cliente registrado en `Clients` |

### 4.6 Decisi\u00f3n para Habitat

- **Copiar el esquema SQLite literalmente** (est\u00e1 completo arriba): est\u00e1
  dise\u00f1ado bien (contenidos deduplicados por hash, fechas con zona horaria en
  blob, enclosures con estado de descarga).
- Parseo: **`xmlTextReader` (libxml2, streaming)** para RSS/Atom/RDF +
  fallback `libtidy`/HTML para feeds rotos \u2014 misma receta que Apple.
- Refresco: timers GLib a 30 min, expiraci\u00f3n 14 d\u00edas, 8 MB de adjuntos.
- El esquema `feeds:`/UUID/filtros es espec\u00edfico de Safari; en Habitat
  basta `http(s)://` (WebKitGTK detecta `<link rel=alternate>` con
  `WebKitWebFeed`/`decide-policy`, sustituyendo `PSDLL_FeedURLCreateFromDOM`).

---

## 5. Resumen de equivalencias Habitat ⇄ Safari 5.1

| Safari 5.1.7 | Habitat (Vala + WebKitGTK) |
|---|---|
| `Bookmarks.plist` (bplist, UUID, Leaf/List/Proxy) | Mismo esquema (JSON/plist v\u00eda GLib) o SQLite; conservar `WebBookmarkUUID` como PK |
| `History.plist` (`WebHistoryDates` por URL) | igual; si usas epoch propio, convierte desde epoch Cocoa (2001-01-01) al importar |
| Notificaciones `WebBookmark*` | Se\u00f1ales GObject con los mismos nombres |
| `TopSites.plist` + UI nativa + `topsites://` | Widget GTK + interceptar `topsites://` en `decide-policy` |
| `ReadingList.plist` / `ReadingList.html` | mismo par datos+vista; `safari-resource:/` \u2192 `file://` o esquema propio |
| `Defaults.plist` (87 claves) | GSettings con los mismos nombres (omite el prefijo `…ContentPageGroupIdentifier.WebKit2…`) |
| `UserAgents.plist` | copiar estructura; rellenar UA actuales |
| `Reader.html` (HTML/CSS nativo + JS de bindings) | reutilizar HTML/CSS + **escribir el JS** (no existe fuente) |
| `Search.dll` (SW*, \u00edndice propio, peso 1.0) | SQLite FTS5 con API de forma id\u00e9ntica |
| `PubSubDLL.dll` (libxml2 + tidy + SQLite) | copiar esquema SQL + `xmlTextReader` + tidy; refresh 30 min/14 d/8 MB |

---

## 6. Evidencias REA de este documento

| Evidencia | Contenido |
|---|---|
| `ev_8e6b5b7094bec10fbab932d9bc3fba7aec0ec6e4b7fef31e0d6fa71c9478e06d` | strings `WebBookmark*` (tipos Leaf/List/Proxy + 7 notificaciones) |
| `ev_697a4b6580d78addcf5c236524fb5ea69f77bb29fa350cc8bbb3e155c070d5a0` | string `Bookmarks.plist` @`0x105008b0` |
| `ev_e87af8cdcd194b940e0ae80ded4d012e8394b17f0edea32bb4bac7faddf0f686` | xref `Bookmarks.plist` → `0x1010869f` |
| `ev_3cf2841af1db513c87f511bf7a0530ab51760a9865ebd6e47defcf02c539b67d` | `FUN_10108670`: singleton CFURL de `Bookmarks.plist` |
| `ev_1c466508c17c11af3f384cf81c55278b66da9e17b5b034940e1cf6fe0191bc53` | xref `TopSites.plist` → `FUN_100c6220` |
| `ev_41cbb9489bce7f05d7976af183f20983713535d4395f3ff3ab7f8d066ba76b64` | xref `ReadingList.plist` → `FUN_101005e0` |
| `ev_4c3f9bc4c2b247a7b533641f398b617420b50747d28c51892c31dec90bb75cab` | xrefs `WebHistoryDates` → `FUN_10233a90`, `FUN_102398b0` |
| `ev_b283d9b5a56dd6c28f1626a256245fa92ac9bc6f6d81f18f310e36744d25fe04` | claves `lastVisitedDate`/`visitCount`/`redirectURLs`/`URLString`/`Title`/`URIDictionary` |
| `ev_34ea706e1b52c95a6888683a3d6cde52f0f0db5995add6deb56b6c8d735acdc7` | `FUN_10106490`: singleton de la clave `URIDictionary` |
| `ev_8a91f8b85811d07b6761ee4e33a2db0cda2dfc0a72c8fb25c72dfc1623cafa29` | `SWSearch` (`Search.dll`, `0x10001c90`) |
| `ev_c81e87d0977a2b68559b92280ac4e41fd67d3d7621d08c041b23262890199a3b` | `FUN_10001280`: normalizaci\u00f3n+tokenizaci\u00f3n+scorer 1.0 |
| `ev_8a9c70758218bf3983f14cbc4f44e20f671bfd88ef8b08bd632e2586a4098fbc` | `PSDLL_IsFeedURL` (`PubSubDLL.dll`) |
| `ev_f9a675168ef574662c8ca928573c8580f9d4e03c633a58f362a96feb461f03c5` | detector de esquema `http` |
| `ev_b2e389af29a23aaa0ae199f0b6401b1b48795b146952de7b8ac27b986444f7bd` | detector de esquema `feeds` |
| `ev_f1745f835b17f40e2b74bfbdc025989f6226abf32f80816f4dcdb215d54bb9c4` | 231 strings de RSS: SQL, acciones, triggers |
| `ev_1b33ac8003fecf21f2db16f6864c0a18981472515ee0b5ae6d0f64c5d0f1a2d0` | imports de parseo libxml2/libtidy |

Marcas *(grep local)* (bytes de `Safari.dll`, sin Evidencia REA): `topsites://`,
`topsites:`, `Safari: TopSites`, `BookmarksBar`/`BookmarksMenu` (4\u00d7),
`safari-resource:/ReadingList.html`, `ReaderJS` + `preparePrintingMailingFrame`.

## 7. Limitaciones

- Las **clases C++ en memoria** de WebBookmarks/WebHistory no se descompilaron
  campo a campo: el modelo **en disco** est\u00e1 completo (claves, tipos, ficheros,
  funciones de I/O), pero los offsets de los objetos en RAM no. Reabrir
  `Safari.dll` en REA (~8\u201310 min de an\u00e1lisis) permitir\u00eda completarlo.
- `topsites://` y las carpetas especiales provienen de b\u00fasqueda literal en los
  bytes (grep), no de una Evidencia Ghidra.
- El HTML/JS de los 42 paneles de UI y de Reader **no se ejecut\u00f3**; es
  an\u00e1lisis est\u00e1tico.
- `habitat-assets\` contiene copias de un perfil de usuario real: tratarlo
  como datos privados.

## 8. Ficheros entregados

- `HABITAT.md` — este documento.
- `habitat-assets\`: `Reader.html`, `Defaults.plist`, `UserAgents.plist`
  (recursos de la instalaci\u00f3n) + `Bookmarks.plist`, `History.plist`,
  `TopSites.plist`, `ReadingList.plist`, `PubSub-Database.sqlite3`
  (perfil real).
- `inspect-safari\Search.dll`, `inspect-safari\PubSubDLL.dll` — clonados en
  esta fase (m\u00e1s `Safari.dll`, `Safari.exe`, `WebKit.dll`,
  `JavaScriptCore.dll`, `WebKitQuartzCoreAdditions.dll`,
  `WebKit2WebProcess.exe` de fases anteriores).
