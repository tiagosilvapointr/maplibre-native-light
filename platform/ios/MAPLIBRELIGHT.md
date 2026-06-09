# MapLibreLight — Exclusion Report

`MapLibreLight.xcframework` is a trimmed variant of `MapLibre.xcframework`
built from the same source tree. It drops style-layer types, source
types, public Obj-C wrappers, optional subsystems, bundled assets, and
vendor dependencies that aren't needed by vector-tile-only iOS clients.

**Final size:**
`MapLibre.dynamic.xcframework` 21.61 MB → `MapLibreLight.dynamic.xcframework`
**17.95 MB** (~17 % smaller compressed).

Build command:

```
bazel build //platform/ios:MapLibreLight.dynamic --//:renderer=metal
bazel build //platform/ios:MapLibreLight.static  --//:renderer=metal
```

The standard `MapLibre.dynamic` build is **bit-for-bit unchanged** — every
source edit inside `src/mbgl/` and `platform/default/` is guarded by a
`MBGL_LAYER_*_DISABLE_ALL` / `MBGL_SOURCE_*_DISABLE_ALL` macro that is
only set on `mbgl-core-light`.

---

## 1. Style layer types — fully removed

| Layer type | What's gone |
|---|---|
| `raster` | render layer + factory + impl + tweaker + style/properties .cpp + Metal shader + Obj-C wrapper (`MLNRasterStyleLayer`) |
| `hillshade` | same set + `hillshade_bucket.cpp` + `hillshade_conversions.cpp` + Obj-C wrapper (`MLNHillshadeStyleLayer`) |
| `heatmap` | same set + `heatmap_bucket.cpp` + Obj-C wrapper (`MLNHeatmapStyleLayer`) |
| `color-relief` | same set + Obj-C wrapper (`MLNColorReliefStyleLayer`) |
| `location-indicator` | render layer + factory + impl + tweaker + style/properties + Metal shader (no Obj-C wrapper existed) |
| `custom` (OpenGL custom layer) | Obj-C wrapper (`MLNCustomStyleLayer`) — the OpenGL impl is naturally excluded by the Metal-only build |
| `custom-drawable` (experimental Metal) | full pipeline + Obj-C wrapper (`MLNCustomDrawableStyleLayer`) |

The Metal shader pipelines `mtl/{heatmap,heatmap_texture,hillshade,
hillshade_prepare,raster,color_relief,location_indicator}.cpp` are all
dropped; the `initShaders` registration in
`src/mbgl/mtl/renderer_backend.cpp` is gated to skip them.

---

## 2. Source types — fully removed

| Source type | What's gone |
|---|---|
| `raster` | `style::RasterSource` impl + render source + raster tile + raster tile worker + JSON parser case in `style/conversion/source.cpp` + render-source dispatcher case in `renderer/render_source.cpp` + offline downloader case + `MLNRasterTileSource` Obj-C wrapper |
| `raster-dem` | `style::RasterDEMSource` impl + render source + raster-dem tile + worker + parser/dispatcher/offline cases + `MLNRasterDEMSource` Obj-C wrapper |
| `image` | `style::ImageSource` impl + render image source + parser/dispatcher/offline cases + `MLNImageSource` Obj-C wrapper |

Styles requesting any of those source types now get a
`"<type> sources are disabled in this build"` parse error and the source
is dropped — the rest of the style still loads.

---

## 3. Other public Obj-C wrappers dropped

- `MLNMapSnapshotter` (+ private header + `.mm`) and the underlying
  `map_snapshotter.cpp`.
- `MLNComputedShapeSource` (+ private header + `.mm`).

---

## 4. `mbgl-default-light` (storage / loop layer) differences

vs `mbgl-default`:

- ❌ `map/map_snapshotter.cpp` — no off-screen rendering.
- ❌ `gfx/headless_frontend.cpp` — same.
- ❌ `mtl/headless_backend.cpp` — same (the live `MLNMapView` uses
  on-screen Metal).
- ❌ `util/png_writer.cpp` — only used by `encodePNG` for snapshots.
- 🔄 `storage/pmtiles_file_source.cpp` → swapped for
  `pmtiles_file_source_stub.cpp` (no boost::spirit / pmtiles vendor lib;
  `pmtiles://` URLs return `nullptr`).
- ✅ `gfx/headless_backend.cpp` kept (carries the
  `Backend::enableGPUExpressionEval` static referenced by
  `line_layer_tweaker`).
- ✅ All other storage (asset, db, file source manager, request, local
  file, main resource loader, mbtiles, offline, offline_database,
  offline_download, online file source, sqlite) preserved — vector
  tiles still fetch, cache, and offline-download normally.

---

## 5. Text shaping

`mbgl-core-light` is built **without HarfBuzz** (the
`harfbuzz_text_shaping` select branch is omitted). Legacy shaping is
used, and the `//vendor:harfbuzz` + `//vendor:freetype` deps are not
linked. Complex-script rendering (Indic, Arabic, Thai) is lower quality
than the standard build.

---

## 6. Renderer

Light core is **Metal only** — hardcodes `MLN_RENDER_BACKEND_METAL=1`
and does not pull in `MLN_DRAWABLES_GL_SOURCE`. OpenGL ES is not
available in the light xcframework.

---

## 7. Vendor dependencies dropped

- `//vendor:pmtiles`.
- `//vendor:freetype` + `//vendor:harfbuzz` (implicit, via the shaping
  switch).

All other core vendor deps (boost, earcut, eternal, expected-lite,
maplibre-native-base, metal-cpp, parsedate, polylabel, protozero,
rapidjson, supercluster, unique_resource, unordered_dense, vector-tile,
wagyu, mlt_cpp, ghc_filesystem, ICU) are retained.

---

## 8. Public API surface

The shipped umbrella header has `#define MLN_LIGHT_BUILD 1` prepended,
then re-imports the source `Mapbox.h` which gates the dropped headers.
The following imports are **not** available:

```
MLNBackgroundStyleLayer.h        (still exists in the SDK but not shipped through the umbrella)
MLNComputedShapeSource.h
MLNCustomDrawableStyleLayer.h
MLNCustomStyleLayer.h
MLNHeatmapStyleLayer.h
MLNHillshadeStyleLayer.h
MLNImageSource.h
MLNMapSnapshotter.h
MLNRasterDEMSource.h
MLNRasterStyleLayer.h
MLNRasterTileSource.h
MLNColorReliefStyleLayer.h
```

Everything else (`MLNMapView`, `MLNStyle`, `MLNVectorStyleLayer` and its
subclasses for fill/line/symbol/fill-extrusion/circle, `MLNShape` /
`MLNFeature` hierarchy, `MLNShapeSource`, `MLNVectorTileSource`,
`MLNUserLocation` / `MLNUserLocationAnnotationView`, `MLNMapCamera`,
`MLNLoggingConfiguration`, `MLNOfflineStorage` and friends, plugin
layer infrastructure including `MLNGLTFPluginLayer`) is preserved
unchanged.

---

## 9. Preprocessor defines set on `mbgl-core-light`

```
MLN_RENDER_BACKEND_METAL=1
MBGL_LAYER_RASTER_DISABLE_ALL=1
MBGL_LAYER_HILLSHADE_DISABLE_ALL=1
MBGL_LAYER_HEATMAP_DISABLE_ALL=1
MBGL_LAYER_COLOR_RELIEF_DISABLE_ALL=1
MBGL_LAYER_LOCATION_INDICATOR_DISABLE_ALL=1
MBGL_LAYER_CUSTOM_DISABLE_ALL=1
MLN_LAYER_CUSTOM_DRAWABLE_DISABLE_ALL=1
MBGL_SOURCE_RASTER_DEM_DISABLE_ALL=1
MBGL_SOURCE_IMAGE_DISABLE_ALL=1
GLES_SILENCE_DEPRECATION=1
```

The Obj-C wrapper libraries also see `MLN_LIGHT_BUILD=1` (added to
`LIGHT_OBJC_DEFINES`).

---

## 10. Source files edited inside `src/mbgl/` and `platform/default/`

All edits are guarded by the existing `MBGL_LAYER_*_DISABLE_ALL` /
`MBGL_SOURCE_*_DISABLE_ALL` macros.

| File | What was conditionally gated |
|---|---|
| `src/mbgl/renderer/render_source.cpp` | `SourceType::Raster` / `RasterDEM` / `Image` cases + their `#include`s |
| `src/mbgl/style/conversion/source.cpp` | `convertRasterSource` / `convertRasterDEMSource` / `convertImageSource` + dispatch branches + `#include`s |
| `platform/default/src/mbgl/storage/offline_download.cpp` | `SourceType::Raster` / `RasterDEM` / `Image` case bodies (both loops) + `#include`s |
| `src/mbgl/mtl/renderer_backend.cpp` | `initShaders` `registerTypes<...>` entries for `Heatmap*Shader`, `Hillshade*Shader`, `RasterShader`, `ColorReliefShader`, `LocationIndicator*Shader`, `CustomGeometryShader`, `CustomSymbolIconShader`, `WideVectorShader` |
| `src/mbgl/style/conversion/constant.cpp` | Explicit template instantiations: `Converter<HillshadeMethodType>`, `Converter<HillshadeIlluminationAnchorType>`, `Converter<RasterResamplingType>` |
| `src/mbgl/style/conversion/property_value.cpp` | Explicit template instantiations: `PropertyValue<HillshadeMethodType>`, `PropertyValue<HillshadeIlluminationAnchorType>`, `PropertyValue<RasterResamplingType>`, `PropertyValue<vector<Color>>` |
| `src/mbgl/style/conversion/function.cpp` | Explicit template instantiations: `convertFunctionToExpression<HillshadeMethodType>`, `<HillshadeIlluminationAnchorType>`, `<RasterResamplingType>`, `<vector<Color>>` |

Plus, in the iOS Obj-C tree:

| File | Edit |
|---|---|
| `platform/ios/src/Mapbox.h` | `#import` of every dropped header wrapped in `#if !defined(MLN_LIGHT_BUILD)` |
| `platform/darwin/src/MLNStyle.mm` | Imports and `sourceFromMBGLSource` raster/raster-dem/image branches gated |
| `platform/darwin/src/MLNStyleLayerManager.mm` | `_Private.h` imports gated to match the existing factory-registration gates |
| `platform/darwin/src/MLNTileSource.mm` | DEM-encoding option block gated by `MLN_LIGHT_BUILD` |

---

## 11. Bazel infrastructure added

None of it touches standard build paths.

| File | Purpose |
|---|---|
| `bazel/core_light.bzl` | Filtered source / header lists + `LIGHT_DISABLED_LAYER_DEFINES` + `LIGHT_OBJC_DEFINES` |
| `bazel/core.bzl` (small split) | `MLN_CORE_SOURCE_COLOR_SELECT` extracted from `MLN_CORE_SOURCE` so the list stays iterable in Starlark |
| `BUILD.bazel` (root) | New `mbgl-core-light` cc_library (Metal-only, legacy shaping, no PMTiles vendor) |
| `platform/default/BUILD.bazel` | New `mbgl-default-light` + `utf_conversion_light` cc_libraries |
| `platform/darwin/BUILD.bazel` + `bazel/files.bzl` | Light filegroups + `darwin-{objc,objcpp,loop,generated-style-artifacts}-light` libraries + `_LIGHT_EXCLUDED_*` lists for Obj-C wrappers |
| `platform/BUILD.bazel` | `objc{,pp}-sdk-light` + `objc-headers-light` + `ios-sdk-light{,-dynamic}` |
| `platform/ios/BUILD.bazel` | `MapLibreLight.{static,dynamic}` xcframework targets + `mapbox_h_light` genrule that bakes `#define MLN_LIGHT_BUILD 1` into the shipped umbrella header + `ios_objcpp_srcs_light` filegroup |

---

## 12. What was intentionally kept

So you know where else the binary spends bytes (and where further
trimming would go):

- Annotation subsystem (`src/mbgl/annotation/*` and all `MLNMapView`
  `addAnnotation:` paths) — `Map::Impl` holds an `AnnotationManager` by
  value; removing it requires `map_impl.hpp` + `map.cpp` surgery.
- Offline storage (`MLNOfflineStorage`, `MLNOfflinePack`,
  `MLNOfflineRegion`, `MLNTilePyramidOfflineRegion`,
  `MLNShapeOfflineRegion`) — `MLNMapView` initializes the cache through
  it.
- `MLNNetworkConfiguration`, `MLNSettings` — both referenced by
  `MLNMapView` / `MLNStyle`.
- `MLNBackgroundStyleLayer` (the C++ background layer remains; the
  Obj-C wrapper header was dropped, but it can be re-added if you want
  to construct background layers programmatically).
- Plugin layer infrastructure (kept — `hudhud::gltf-model-layer` and
  similar work).
- All vector-tile, GeoJSON, fill, line, symbol, circle, fill-extrusion,
  custom-vector-source code paths.
- Most localizations except non-`Base.lproj` (already dropped from
  resources).
- The annotation API surface on `MLNMapView` (compiles + links; runtime
  behavior unchanged).
