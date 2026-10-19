#ifndef WEBVIEW2_BRIDGE_H
#define WEBVIEW2_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Estructura opaca para representar el puente
typedef struct WebView2Bridge WebView2Bridge;

// Callbacks que Vala implementará
typedef void (*WebView2URLChangedCallback)(const char* url, void* user_data);
typedef void (*WebView2TitleChangedCallback)(const char* title, void* user_data);
typedef void (*WebView2InitReadyCallback)(void* user_data);
typedef void (*WebView2NavStartingCallback)(const char* url, void* user_data);
typedef void (*WebView2NavCompletedCallback)(int is_success, const char* error, void* user_data);
typedef void (*WebView2HistoryChangedCallback)(int can_go_back, int can_go_forward, void* user_data);

// Crea una nueva instancia del puente.
WebView2Bridge* webview2_bridge_new(void);

// Inicializa el WebView2 asíncronamente en el HWND dado.
// hwnd: HWND (void*) del widget Gtk.
// offset_y: Espacio reservado arriba (para la barra de GTK).
// user_data_dir: Directorio para cookies, caché y perfil (o NULL).
// ready_cb: Callback que se ejecuta cuando el WebView2 está listo.
// user_data: Puntero de contexto.
void webview2_bridge_initialize(WebView2Bridge* bridge,
                                void* hwnd,
                                int offset_y,
                                const char* user_data_dir,
                                WebView2InitReadyCallback ready_cb,
                                void* user_data);

// Destruye el puente y libera los recursos.
void webview2_bridge_free(WebView2Bridge* bridge);

// Establece callbacks individuales
void webview2_bridge_set_url_changed_callback(WebView2Bridge* bridge, WebView2URLChangedCallback cb, void* user_data);
void webview2_bridge_set_title_changed_callback(WebView2Bridge* bridge, WebView2TitleChangedCallback cb, void* user_data);
void webview2_bridge_set_nav_starting_callback(WebView2Bridge* bridge, WebView2NavStartingCallback cb, void* user_data);
void webview2_bridge_set_nav_completed_callback(WebView2Bridge* bridge, WebView2NavCompletedCallback cb, void* user_data);
void webview2_bridge_set_history_changed_callback(WebView2Bridge* bridge, WebView2HistoryChangedCallback cb, void* user_data);

// Compatibilidad con la versión básica previa
void webview2_bridge_set_callbacks(WebView2Bridge* bridge,
                                   WebView2URLChangedCallback url_cb,
                                   void* url_user_data,
                                   WebView2TitleChangedCallback title_cb,
                                   void* title_user_data);

// Navegación
void webview2_bridge_navigate(WebView2Bridge* bridge, const char* url);
void webview2_bridge_reload(WebView2Bridge* bridge);
void webview2_bridge_stop(WebView2Bridge* bridge);
void webview2_bridge_go_back(WebView2Bridge* bridge);
void webview2_bridge_go_forward(WebView2Bridge* bridge);
int webview2_bridge_can_go_back(WebView2Bridge* bridge);
int webview2_bridge_can_go_forward(WebView2Bridge* bridge);

// Scripts, zoom y foco
void webview2_bridge_execute_script(WebView2Bridge* bridge, const char* js);
void webview2_bridge_set_zoom(WebView2Bridge* bridge, double zoom);
double webview2_bridge_get_zoom(WebView2Bridge* bridge);
void webview2_bridge_focus(WebView2Bridge* bridge);

// Dimensiones y posición
void webview2_bridge_resize(WebView2Bridge* bridge, int width, int height);
void webview2_bridge_set_offset_y(WebView2Bridge* bridge, int offset_y);

// Helper para obtener el HWND de Windows desde un widget GTK4
void* webview2_get_widget_hwnd(void* gtk_widget);

#ifdef __cplusplus
}
#endif

#endif // WEBVIEW2_BRIDGE_H
