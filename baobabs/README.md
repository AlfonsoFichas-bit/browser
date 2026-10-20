# Baobabs (Habitat)

Navegador minimalista inspirado en Safari 5.1.7 para Windows.

## Objetivo

Clon fiel al espíritu de Safari 5.1.7: interfaz simple, TopSites, ReadingList, Reader, marcadores con UUIDs y modelo de datos basado en la ingeniería inversa realizada con REA.

## Tecnologías

- **Lenguaje**: Vala + GObject
- **UI**: GTK 4
- **Motor web**: WebKitGTK (Linux) como motor por defecto. WebView2 disponible en Windows.
- **Build**: Meson

## Arquitectura

Basado en el análisis de `safari/HABITAT.md`:

- **Bookmarks/History/TopSites/ReadingList**: mantienen formato estilo Safari (.plist). Conversión epoch Cocoa ↔ Unix.
- **Search**: reemplazo de `Search.dll` con SQLite FTS5.
- **RSS/PubSub**: esquema SQLite copiado literalmente de `PubSubDLL.dll` (libxml2 + libtidy).
- **Reader**: reutiliza `Reader.html` con implementación propia de `ReaderJS.*` (no existe en binarios).
- **TopSites**: vista interna + esquema `topsites://` interceptado.

## Estado

Fase inicial. Ver `safari/HABITAT.md` para documentación completa de ingeniería inversa.

### Motor Linux (WebKitGTK)

- **Activo y funcionando**: El proyecto compila y usa WebKitGTK 6.0 como motor por defecto para la versión en Linux. En Windows se mantiene el uso de WebView2.
- **Perfil Persistente**: Los datos del motor se almacenan de manera persistente utilizando el directorio del perfil del usuario (por ejemplo, `~/.config/baobabs/default/webkit`).
- **Limitación en scripts**: La función de ejecutar scripts en páginas usando el motor Linux (`execute_script`) opera de forma asíncrona "fire-and-forget", en la que el resultado es descartado de inmediato.

## Licencia

Por determinar. Base de estudio: Safari 5.1.7 (Windows) — análisis estático únicamente.