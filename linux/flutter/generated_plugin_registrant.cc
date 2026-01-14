//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <ios_color_picker/ios_color_picker_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) ios_color_picker_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "IosColorPickerPlugin");
  ios_color_picker_plugin_register_with_registrar(ios_color_picker_registrar);
}
