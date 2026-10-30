# AGENTS.md — Windows (C# / WinUI)

Este directorio contiene la **reescritura para Windows** del navegador Baobabs (Habitat).

## Objetivo

Construir la versión de Windows del navegador inspirado en Safari 5.1.7, basada
en el trabajo de **ingeniería inversa** realizado con REA y Ghidra sobre el
navegador Safari (binarios, recursos y esquemas de datos), documentado en
`safari/HABITAT.md` y los artefactos de `safari/habitat-assets/`.

## Stack objetivo

- **Motor web:** WebView2
- **Lenguaje:** C#
- **UI:** WinUI

## Alcance

- Portar la funcionalidad ya validada en la versión Linux (Vala + WebKitGTK)
  a Windows usando WebView2, C# y WinUI.
- Reutilizar los modelos de datos y esquemas derivados del análisis de Safari
  (Bookmarks, History, TopSites, ReadingList, Defaults, UserAgents, etc.).
- Mantener compatibilidad con los plists y convenciones documentadas en
  `safari/HABITAT.md`.

## Referencia

- Ingeniería inversa: `safari/HABITAT.md`, `safari/habitat-assets/`, `safari/INFORME.md`.
- Versión legacy Windows (Vala + GTK4 + WebView2): `legacy/windows-vala/`.
- Versión Linux actual: `baobabs/`.
