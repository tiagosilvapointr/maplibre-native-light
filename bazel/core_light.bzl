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
# Couplings we can NOT untangle in this first pass (notes for future work):
#
#   * `src/mbgl/style/source.cpp` constructs `ImageSource` / `RasterSource`
#     / `RasterDEMSource` directly when parsing JSON → keep their .cpp
#     impls in the light core.
#   * `mbgl::OfflineDownload` calls `ImageSource::getURL()` → same.
#   * `mtl::renderer_backend` instantiates a `ShaderSource<BuiltIn>` for
#     every entry in the BuiltIn enum → keep all Metal shader .cpp files.
#   * Generic style/conversion code references the enum-string converters
#     defined in `hillshade_layer.cpp` (HillshadeMethodType) and
#     `color_relief_layer.cpp` (vector<Color>) → keep those generated
#     style .cpp files.
#   * `RasterDEMTile` uses `HillshadeBucket` → keep hillshade_bucket.cpp.
#   * `RenderStaticData::heatmapTextureVertices()` uses
#     `HeatmapBucket::textureVertex` → keep heatmap_bucket.cpp.
#
# What we CAN drop safely: the render-layer .cpp + the LayerFactory .cpp
# + the layer impl + the drawable tweakers, for layer types whose
# `MBGL_LAYER_*_DISABLE_ALL` macro is defined in the light build.
# The factory class is referenced only from `layer_manager.cpp`
# (already gated) and from `MLNStyleLayerManager.mm` (also gated).
# RenderLayer subclasses are constructed only by their factory, so once
# the factory is gone they're unreferenced and safe to omit.

_LIGHT_EXCLUDED_GENERATED_STYLE_SOURCE = [
    # Heatmap is fully removed in MapLibreLight. The factory + impl +
    # render-layer + tweakers are already excluded below, so nothing
    # constructs HeatmapLayer at runtime — its generated .cpp + properties
    # .cpp can also go. style_impl.cpp only `#include`s the header which is
    # fine without the .cpp.
    "src/mbgl/style/layers/heatmap_layer.cpp",
    "src/mbgl/style/layers/heatmap_layer_properties.cpp",
    # Hillshade/raster properties — only referenced from the corresponding
    # _impl.cpp / render-layer.cpp, both excluded below. The matching
    # _layer.cpp files are KEPT (HillshadeMethodType / generic conversion).
    "src/mbgl/style/layers/hillshade_layer_properties.cpp",
    "src/mbgl/style/layers/raster_layer_properties.cpp",
]

_LIGHT_EXCLUDED_CORE_SOURCE = [
    # Layer impls — only referenced by the corresponding factory.cpp
    "src/mbgl/style/layers/heatmap_layer_impl.cpp",
    "src/mbgl/style/layers/hillshade_layer_impl.cpp",
    "src/mbgl/style/layers/raster_layer_impl.cpp",
    "src/mbgl/style/layers/location_indicator_layer_impl.cpp",
    # Layer factories — only registered from layer_manager.cpp (gated)
    "src/mbgl/layermanager/heatmap_layer_factory.cpp",
    "src/mbgl/layermanager/hillshade_layer_factory.cpp",
    "src/mbgl/layermanager/color_relief_layer_factory.cpp",
    "src/mbgl/layermanager/location_indicator_layer_factory.cpp",
    # Render layers — only constructed via their factory
    "src/mbgl/renderer/layers/render_heatmap_layer.cpp",
    "src/mbgl/renderer/layers/render_hillshade_layer.cpp",
    "src/mbgl/renderer/layers/render_color_relief_layer.cpp",
    "src/mbgl/renderer/layers/render_location_indicator_layer.cpp",
    "src/mbgl/renderer/layers/render_raster_layer.cpp",
    # Heatmap bucket — only consumer was render_heatmap_layer.cpp (dropped
    # above). RenderStaticData::heatmapTextureVertices() still compiles
    # because the only HeatmapBucket symbol it touches is the inline
    # `textureVertex()` static defined in heatmap_bucket.hpp.
    "src/mbgl/renderer/buckets/heatmap_bucket.cpp",
]

_LIGHT_EXCLUDED_DRAWABLES_SOURCE = [
    # Tweakers — only referenced by their RenderLayer
    "src/mbgl/renderer/layers/color_relief_layer_tweaker.cpp",
    "src/mbgl/renderer/layers/heatmap_layer_tweaker.cpp",
    "src/mbgl/renderer/layers/heatmap_texture_layer_tweaker.cpp",
    "src/mbgl/renderer/layers/hillshade_layer_tweaker.cpp",
    "src/mbgl/renderer/layers/hillshade_prepare_layer_tweaker.cpp",
    "src/mbgl/renderer/layers/location_indicator_layer_tweaker.cpp",
    "src/mbgl/renderer/layers/raster_layer_tweaker.cpp",
    # Custom-drawable experimental layer (MLN_LAYER_CUSTOM_DRAWABLE_DISABLE_ALL)
    "src/mbgl/style/layers/custom_drawable_layer.cpp",
    "src/mbgl/layermanager/custom_drawable_layer_factory.cpp",
    "src/mbgl/style/layers/custom_drawable_layer_impl.cpp",
    "src/mbgl/renderer/layers/render_custom_drawable_layer.cpp",
]

_LIGHT_EXCLUDED_DRAWABLES_MTL_SOURCE = [
    # Heatmap / Hillshade / Raster Metal shaders — registerTypes<...> in
    # mtl/renderer_backend.cpp gates the corresponding `BuiltIn::*Shader`
    # entries with `MBGL_LAYER_*_DISABLE_ALL`, so the symbols
    # ShaderSource<...>::vertex / ::fragment defined in these .cpp files
    # are no longer referenced.
    "src/mbgl/shaders/mtl/heatmap.cpp",
    "src/mbgl/shaders/mtl/heatmap_texture.cpp",
    "src/mbgl/shaders/mtl/hillshade.cpp",
    "src/mbgl/shaders/mtl/hillshade_prepare.cpp",
    "src/mbgl/shaders/mtl/raster.cpp",
]

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
