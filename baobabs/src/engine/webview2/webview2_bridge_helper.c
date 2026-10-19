#include "webview2_bridge.h"
#include <gtk/gtk.h>
#include <gdk/win32/gdkwin32.h>

void* webview2_get_widget_hwnd(void* widget_ptr) {
    if (!widget_ptr) return NULL;
    GtkWidget* widget = GTK_WIDGET(widget_ptr);
    GtkNative* native = gtk_widget_get_native(widget);
    if (!native) return NULL;
    GdkSurface* surface = gtk_native_get_surface(native);
    if (!surface) return NULL;
    return (void*)gdk_win32_surface_get_handle(surface);
}
