load("@bazel_skylib//rules:common_settings.bzl", "bool_flag")

LAYER_FLAGS = [
    struct(name = "background", macro = "MBGL_LAYER_BACKGROUND_DISABLE_ALL"),
    struct(name = "circle", macro = "MBGL_LAYER_CIRCLE_DISABLE_ALL"),
    struct(name = "color_relief", macro = "MBGL_LAYER_COLOR_RELIEF_DISABLE_ALL"),
    struct(name = "custom", macro = "MBGL_LAYER_CUSTOM_DISABLE_ALL"),
    struct(name = "custom_drawable", macro = "MLN_LAYER_CUSTOM_DRAWABLE_DISABLE_ALL"),
    struct(name = "fill", macro = "MBGL_LAYER_FILL_DISABLE_ALL"),
    struct(name = "fill_extrusion", macro = "MBGL_LAYER_FILL_EXTRUSION_DISABLE_ALL"),
    struct(name = "heatmap", macro = "MBGL_LAYER_HEATMAP_DISABLE_ALL"),
    struct(name = "hillshade", macro = "MBGL_LAYER_HILLSHADE_DISABLE_ALL"),
    struct(name = "line", macro = "MBGL_LAYER_LINE_DISABLE_ALL"),
    struct(name = "location_indicator", macro = "MBGL_LAYER_LOCATION_INDICATOR_DISABLE_ALL"),
    struct(name = "plugin", macro = "MBGL_LAYER_PLUGIN_DISABLE_ALL"),
    struct(name = "raster", macro = "MBGL_LAYER_RASTER_DISABLE_ALL"),
    struct(name = "raster_dem", macro = "MBGL_LAYER_RASTER_DEM_DISABLE_ALL"),
    struct(name = "symbol", macro = "MBGL_LAYER_SYMBOL_DISABLE_ALL"),
]

def layer_flag_settings():
    for layer in LAYER_FLAGS:
        bool_flag(
            name = "enable_layer_{}".format(layer.name),
            build_setting_default = True,
            visibility = ["//visibility:public"],
        )
        native.config_setting(
            name = "layer_{}_disabled".format(layer.name),
            flag_values = {
                ":enable_layer_{}".format(layer.name): "false",
            },
            visibility = ["//visibility:public"],
        )

    native.config_setting(
        name = "layers_raster_and_raster_dem_disabled",
        flag_values = {
            ":enable_layer_raster": "false",
            ":enable_layer_raster_dem": "false",
        },
        visibility = ["//visibility:public"],
    )

def if_layer_enabled(layer, files):
    return select({
        "//:layer_{}_disabled".format(layer): [],
        "//conditions:default": files,
    })

def if_raster_source_enabled(files):
    return select({
        "//:layers_raster_and_raster_dem_disabled": [],
        "//conditions:default": files,
    })

def layer_disable_defines():
    defines = []
    for layer in LAYER_FLAGS:
        values = [layer.macro + "=1"]
        if layer.name == "custom_drawable":
            values.append("MBGL_LAYER_CUSTOM_DRAWABLE_DISABLE_ALL=1")
        defines = defines + select({
            "//:layer_{}_disabled".format(layer.name): values,
            "//conditions:default": [],
        })
    return defines

def layer_disable_define_cmd():
    cmd = ""
    for layer in LAYER_FLAGS:
        lines = ["#define {} 1".format(layer.macro)]
        if layer.name == "custom_drawable":
            lines.append("#define MBGL_LAYER_CUSTOM_DRAWABLE_DISABLE_ALL 1")
        shell = "".join(["printf '%s\\n' '{}' >> $@; ".format(line) for line in lines])
        cmd = cmd + select({
            "//:layer_{}_disabled".format(layer.name): shell,
            "//conditions:default": "",
        })
    return cmd
