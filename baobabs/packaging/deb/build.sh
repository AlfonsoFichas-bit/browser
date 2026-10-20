#!/bin/bash
set -e

# Asegurar que estamos en la raíz del proyecto si el script se llama de cualquier parte
cd "$(dirname "$0")/../../"

# Limpieza inicial
rm -rf builddir
rm -rf packaging/deb/staging

# Meson setup & compile
meson setup builddir --prefix=/usr
meson compile -C builddir

# Install to staging directory
DESTDIR=$(pwd)/packaging/deb/staging meson install -C builddir

# Copy debian control files
cp -r packaging/deb/DEBIAN packaging/deb/staging/

# Build deb
dpkg-deb --build packaging/deb/staging packaging/deb/baobabs_0.1.0_amd64.deb

echo "Paquete construido: packaging/deb/baobabs_0.1.0_amd64.deb"