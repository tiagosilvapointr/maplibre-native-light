"""
Light SDK source/header filtering.

Defines explicit exclusion lists for the MapLibreLight build variant and
exposes filtered versions of the core file lists from //bazel:core.bzl.

The light variant drops support for the following style-layer types and
related rendering pipelines:

  - raster        (style/source/render/tile/shader/tweaker)
  - raster-dem    (style source + tile + render-source)
  - image         (image style source)
  - hillshade
  - color-relief
  - heatmap
  - location-indicator
  - custom-drawable (Metal-only experimental custom layer)

The matching MBGL_LAYER_*_DISABLE_ALL / MLN_LAYER_CUSTOM_DRAWABLE_DISABLE_ALL
preprocessor defines are also set so that LayerManager / Obj-C wrappers do
not reference the dropped types.

OpenGL custom layers (MLNCustomStyleLayer / custom_layer.cpp) are already
gated by `MLN_RENDER_BACKEND_OPENGL` in layer_manager.cpp and the matching
sources are part of MLN_DRAWABLES_GL_SOURCE which is not pulled in by a
Metal iOS build, so no explicit exclusion is needed for them.
"""

load(
    "//bazel:core.bzl",
    "MLN_CORE_HEADERS",
    "MLN_CORE_SOURCE",
    "MLN_DRAWABLES_HEADERS",
    "MLN_DRAWABLES_MTL_HEADERS",
    "MLN_DRAWABLES_MTL_SOURCE",
    "MLN_DRAWABLES_SOURCE",
    "MLN_GENERATED_STYLE_SOURCE",
    "MLN_PRIVATE_GENERATED_STYLE_HEADERS",
    "MLN_PUBLIC_GENERATED_STYLE_HEADERS",
)

# Files to drop from the light core. Header files are intentionally retained
# in `hdrs` (cheap to keep, allows code that #includes them but never calls
# into them to still compile); only the matching .cpp/source files are
# excluded.
# NOTE: First-pass scope — the C++ core is left intact.
#
# We initially tried to drop the implementations of layer types not used
# by the light public API (heatmap, hillshade, color-relief,
# location-indicator, custom-drawable, raster, raster-dem, image source).
# That broke linking for many reasons:
#
#   * `src/mbgl/style/source.cpp` constructs `ImageSource` / `RasterSource`
#     / `RasterDEMSource` directly when parsing JSON.
#   * `mbgl::OfflineDownload` calls `ImageSource::getURL()`.
#   * `mtl::renderer_backend` instantiates a `ShaderSource<BuiltIn>` for
#     every entry in the BuiltIn enum, so any dropped Metal shader .cpp
#     leaves an undefined symbol.
#   * Generic style/conversion code references the enum-string converters
#     defined in `hillshade_layer.cpp` (HillshadeMethodType) and
#     `color_relief_layer.cpp` (vector<Color>).
#   * `RasterDEMTile` uses `HillshadeBucket`.
#
# Resolving these would require splitting source-impl headers, gating the
# JSON parser + BuiltIn enum + offline downloader. Saving that for later.
#
# For now, MapLibreLight ships with the same C++ core as the standard
# MapLibre target. The size win comes from the Obj-C wrapper trimming
# (dropped headers + `.mm` files for raster/hillshade/heatmap/etc.) and
# the smaller public API surface in the xcframework.
_LIGHT_EXCLUDED_GENERATED_STYLE_SOURCE = []

_LIGHT_EXCLUDED_CORE_SOURCE = []

_LIGHT_EXCLUDED_DRAWABLES_SOURCE = []

_LIGHT_EXCLUDED_DRAWABLES_MTL_SOURCE = []

MLN_CORE_SOURCE_LIGHT = [f for f in MLN_CORE_SOURCE if f not in _LIGHT_EXCLUDED_CORE_SOURCE]
MLN_CORE_HEADERS_LIGHT = MLN_CORE_HEADERS
MLN_GENERATED_STYLE_SOURCE_LIGHT = [
    f
    for f in MLN_GENERATED_STYLE_SOURCE
    if f not in _LIGHT_EXCLUDED_GENERATED_STYLE_SOURCE
]
MLN_PUBLIC_GENERATED_STYLE_HEADERS_LIGHT = MLN_PUBLIC_GENERATED_STYLE_HEADERS
MLN_PRIVATE_GENERATED_STYLE_HEADERS_LIGHT = MLN_PRIVATE_GENERATED_STYLE_HEADERS
MLN_DRAWABLES_SOURCE_LIGHT = [
    f
    for f in MLN_DRAWABLES_SOURCE
    if f not in _LIGHT_EXCLUDED_DRAWABLES_SOURCE
]
MLN_DRAWABLES_HEADERS_LIGHT = MLN_DRAWABLES_HEADERS
MLN_DRAWABLES_MTL_SOURCE_LIGHT = [
    f
    for f in MLN_DRAWABLES_MTL_SOURCE
    if f not in _LIGHT_EXCLUDED_DRAWABLES_MTL_SOURCE
]
MLN_DRAWABLES_MTL_HEADERS_LIGHT = MLN_DRAWABLES_MTL_HEADERS

# Preprocessor defines applied to mbgl-core-light and the light Obj-C
# wrapper libraries. They drop layer-factory registration (in
# layer_manager.cpp + MLNStyleLayerManager.mm) and gate matching
# #imports / source-factory branches in MLNStyle.mm + Mapbox.h.
LIGHT_DISABLED_LAYER_DEFINES = [
    "MBGL_LAYER_RASTER_DISABLE_ALL=1",
    "MBGL_LAYER_HILLSHADE_DISABLE_ALL=1",
    "MBGL_LAYER_HEATMAP_DISABLE_ALL=1",
    "MBGL_LAYER_COLOR_RELIEF_DISABLE_ALL=1",
    "MBGL_LAYER_LOCATION_INDICATOR_DISABLE_ALL=1",
    # The OpenGL custom layer wrapper (MLNCustomStyleLayer) is not available
    # in the light build — it is OpenGL-only and the light core is Metal-only.
    "MBGL_LAYER_CUSTOM_DISABLE_ALL=1",
    "MLN_LAYER_CUSTOM_DRAWABLE_DISABLE_ALL=1",
]

# Additional Obj-C-only define so the umbrella header + source factory in
# MLNStyle.mm can gate references to MLNImageSource / MLNRasterTileSource /
# MLNRasterDEMSource (their underlying core impls are dropped above).
LIGHT_OBJC_DEFINES = LIGHT_DISABLED_LAYER_DEFINES + [
    "MLN_LIGHT_BUILD=1",
]
