#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif
#include <glib.h>
#include <glib/gstdio.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Helper to resolve the absolute path to the app icon
static gchar* resolve_app_icon_path() {
  g_autoptr(GError) error = nullptr;
  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", &error);
  if (exe_path != nullptr) {
    g_autofree gchar* exe_dir = g_path_get_dirname(exe_path);

    // 1. Try bundle root ordo.png
    g_autofree gchar* bundle_icon = g_build_filename(exe_dir, "ordo.png", nullptr);
    if (g_file_test(bundle_icon, G_FILE_TEST_EXISTS)) {
      return g_strdup(bundle_icon);
    }

    // 2. Try data/flutter_assets/assets/images/app_logo.png relative to executable
    g_autofree gchar* asset_icon = g_build_filename(
        exe_dir, "data", "flutter_assets", "assets", "images", "app_logo.png", nullptr);
    if (g_file_test(asset_icon, G_FILE_TEST_EXISTS)) {
      return g_strdup(asset_icon);
    }
  }

  // Fallback to relative paths
  const gchar* fallback_paths[] = {
      "ordo.png",
      "data/flutter_assets/assets/images/app_logo.png",
      "assets/images/app_logo.png",
      nullptr
  };
  for (int i = 0; fallback_paths[i] != nullptr; ++i) {
    if (g_file_test(fallback_paths[i], G_FILE_TEST_EXISTS)) {
      return g_strdup(fallback_paths[i]);
    }
  }
  return nullptr;
}

// Ensure ~/.local/share/applications/ordo.desktop and icons are registered so KDE / Wayland taskbar
// associates the window app_id with the mobile app icon.
static void register_xdg_desktop_integration(const gchar* icon_path) {
  if (icon_path == nullptr) return;

  g_autoptr(GError) error = nullptr;
  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", &error);
  if (exe_path == nullptr) return;

  const gchar* data_home = g_get_user_data_dir(); // Typically ~/.local/share
  g_autofree gchar* apps_dir = g_build_filename(data_home, "applications", nullptr);
  g_mkdir_with_parents(apps_dir, 0755);

  // Register icon in ~/.local/share/icons/hicolor/512x512/apps/
  g_autofree gchar* icons_dir = g_build_filename(data_home, "icons", "hicolor", "512x512", "apps", nullptr);
  g_mkdir_with_parents(icons_dir, 0755);

  const gchar* icon_names[] = {"ordo.png", "com.ordo.app.png", nullptr};
  for (int i = 0; icon_names[i] != nullptr; ++i) {
    g_autofree gchar* target_icon = g_build_filename(icons_dir, icon_names[i], nullptr);
    if (!g_file_test(target_icon, G_FILE_TEST_EXISTS)) {
      g_autoptr(GFile) src_file = g_file_new_for_path(icon_path);
      g_autoptr(GFile) dst_file = g_file_new_for_path(target_icon);
      g_file_copy(src_file, dst_file, G_FILE_COPY_OVERWRITE, nullptr, nullptr, nullptr, nullptr);
    }
  }

  // Write desktop files for both "ordo.desktop" and "com.ordo.app.desktop"
  const gchar* desktop_names[] = {"ordo.desktop", "com.ordo.app.desktop", nullptr};
  const gchar* desktop_template =
      "[Desktop Entry]\n"
      "Version=1.0\n"
      "Type=Application\n"
      "Name=ordo\n"
      "GenericName=知序 · Ordo\n"
      "Comment=知序 · 个人任务与项目管理\n"
      "Exec=\"%s\" %%u\n"
      "Icon=ordo\n"
      "Terminal=false\n"
      "Categories=Office;Utility;\n"
      "StartupWMClass=ordo\n";
  g_autofree gchar* desktop_content = g_strdup_printf(desktop_template, exe_path);

  for (int i = 0; desktop_names[i] != nullptr; ++i) {
    g_autofree gchar* desktop_path = g_build_filename(apps_dir, desktop_names[i], nullptr);
    g_file_set_contents(desktop_path, desktop_content, -1, nullptr);
  }
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling visual cues.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "ordo");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "ordo");
  }

  // Load app icon (resolved absolutely from executable path or bundle)
  g_autofree gchar* icon_path = resolve_app_icon_path();
  if (icon_path != nullptr) {
    gtk_window_set_icon_from_file(window, icon_path, nullptr);
    gtk_window_set_default_icon_from_file(icon_path, nullptr);
    register_xdg_desktop_integration(icon_path);
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname("ordo");
  g_set_application_name("ordo");

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
