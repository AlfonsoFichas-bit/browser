# Baobabs (Habitat)

Navegador minimalista inspirado en Safari 5.1.7 para Windows.

## Objetivo

Clon fiel al espíritu de Safari 5.1.7: interfaz simple, TopSites, ReadingList, Reader, marcadores con UUIDs y modelo de datos basado en la ingeniería inversa realizada con REA.

## Tecnologías

- **Lenguaje**: Vala + GObject
- **UI**: GTK 4
- **Motor web**: WebView2 (Windows-first). Preparado para WebKitGTK (Linux).
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

## Instalación (Linux)

Baobabs ofrece soporte multimedia integral mediante GStreamer para WebKitGTK 6.0 en Linux (códecs como H.264 y AAC).

### Método 1: Instalación vía Flatpak (Recomendado)
El método Flatpak instala y configura un entorno completo haciendo uso del runtime de GNOME, lo que garantiza el correcto funcionamiento de los videos y sonidos de inmediato.

```bash
flatpak-builder --user --install build-flatpak packaging/flatpak/org.baobabs.browser.yml --force-clean
flatpak run org.baobabs.browser
```

### Método 2: Paquete Debian (.deb)
Baobabs cuenta con un script que permite generar un archivo `.deb`.

```bash
cd packaging/deb
./build.sh
```

Al instalar el archivo `.deb`, dependencias vitales de códecs se instalan de manera recomendada mediante GStreamer. En Ubuntu y derivadas, es necesario asegurarse que el repositorio **multiverse** esté activado para que `apt` pueda encontrar los plugins multimedia `bad` y `ugly`.

```bash
sudo add-apt-repository multiverse
sudo apt update
sudo dpkg -i packaging/deb/baobabs_0.1.0_amd64.deb
sudo apt-get install -f
```

### Método 3: Paquete Snap
Baobabs cuenta también con soporte para ser empaquetado y distribuido como formato de aplicación Snap en distribuciones que lo soporten haciendo uso del entorno base de GNOME que provee sus códecs integrados.

```bash
cd packaging/snap
snapcraft
sudo snap install baobabs_0.1.0_amd64.snap --dangerous
```

## Licencia

Por determinar. Base de estudio: Safari 5.1.7 (Windows) — análisis estático únicamente.