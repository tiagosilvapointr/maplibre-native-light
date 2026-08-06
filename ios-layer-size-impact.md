# iOS Layer Size Impact

Generated: 2026-06-04 18:39:05 UTC

Target: `//platform/ios:MapLibre.dynamic`

Renderer: `metal`

Reports: [`ios-layer-size-reports/20260604-213905`](ios-layer-size-reports/20260604-213905)

| Variant | Disabled flag | Device binary bytes | Delta bytes | Delta % | Stripped binary bytes | Stripped saved bytes | Stripped saved % | Zip bytes | Bloaty report | Status |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| `baseline` | `none` | 15896552 | 0 | 0.00% | 6303448 | 0 | 0.00% | 12077009 | [bloaty_symbols_file_top100.txt](ios-layer-size-reports/20260604-213905/baseline/bloaty_symbols_file_top100.txt) | ok |
| `background` | `--//:enable_layer_background=false` | 15810792 | -85760 | -0.54% | 6270144 | 33304 | 0.53% | 12023941 | [bloaty_symbols_file_top100.txt](ios-layer-size-reports/20260604-213905/background/bloaty_symbols_file_top100.txt) | ok |
| `circle` | `--//:enable_layer_circle=false` | 15654424 | -242128 | -1.52% | 6204192 | 99256 | 1.57% | 11941353 | [bloaty_symbols_file_top100.txt](ios-layer-size-reports/20260604-213905/circle/bloaty_symbols_file_top100.txt) | ok |
| `color-relief` | `--//:enable_layer_color_relief=false` | 15813440 | -83112 | -0.52% | 6270144 | 33304 | 0.53% | 12023526 | [bloaty_symbols_file_top100.txt](ios-layer-size-reports/20260604-213905/color-relief/bloaty_symbols_file_top100.txt) | ok |
| `custom` | `--//:enable_layer_custom=false` | 15851688 | -44864 | -0.28% | 6286680 | 16768 | 0.27% | 12049876 | [bloaty_symbols_file_top100.txt](ios-layer-size-reports/20260604-213905/custom/bloaty_symbols_file_top100.txt) | ok |
| `custom-drawable` | `--//:enable_layer_custom_drawable=false` | 15881776 | -14776 | -0.09% | 6303152 | 296 | 0.00% | 12063899 | [bloaty_symbols_file_top100.txt](ios-layer-size-reports/20260604-213905/custom-drawable/bloaty_symbols_file_top100.txt) | ok |
| `fill` | `--//:enable_layer_fill=false` | 15702912 | -193640 | -1.22% | 6220672 | 82776 | 1.31% | 11955825 | [bloaty_symbols_file_top100.txt](ios-layer-size-reports/20260604-213905/fill/bloaty_symbols_file_top100.txt) | ok |
| `fill-extrusion` | `--//:enable_layer_fill_extrusion=false` | 15708264 | -188288 | -1.18% | 6220704 | 82744 | 1.31% | 11962232 | [bloaty_symbols_file_top100.txt](ios-layer-size-reports/20260604-213905/fill-extrusion/bloaty_symbols_file_top100.txt) | ok |
| `heatmap` | `--//:enable_layer_heatmap=false` | 15789192 | -107360 | -0.68% | 6270024 | 33424 | 0.53% | 11996888 | [bloaty_symbols_file_top100.txt](ios-layer-size-reports/20260604-213905/heatmap/bloaty_symbols_file_top100.txt) | ok |
| `hillshade` | `--//:enable_layer_hillshade=false` | 15648504 | -248048 | -1.56% | 6204104 | 99344 | 1.58% | 11941927 | [bloaty_symbols_file_top100.txt](ios-layer-size-reports/20260604-213905/hillshade/bloaty_symbols_file_top100.txt) | ok |
| `line` | `--//:enable_layer_line=false` | 15638128 | -258424 | -1.63% | 6204136 | 99312 | 1.58% | 11906418 | [bloaty_symbols_file_top100.txt](ios-layer-size-reports/20260604-213905/line/bloaty_symbols_file_top100.txt) | ok |
| `location-indicator` | `--//:enable_layer_location_indicator=false` | 15896552 | 0 | 0.00% | 6303448 | 0 | 0.00% | 12077089 | [bloaty_symbols_file_top100.txt](ios-layer-size-reports/20260604-213905/location-indicator/bloaty_symbols_file_top100.txt) | ok |
| `plugin` | `--//:enable_layer_plugin=false` | 15787896 | -108656 | -0.68% | 6253208 | 50240 | 0.80% | 12008857 | [bloaty_symbols_file_top100.txt](ios-layer-size-reports/20260604-213905/plugin/bloaty_symbols_file_top100.txt) | ok |
| `raster` | `--//:enable_layer_raster=false` | 15630952 | -265600 | -1.67% | 6203720 | 99728 | 1.58% | 11898950 | [bloaty_symbols_file_top100.txt](ios-layer-size-reports/20260604-213905/raster/bloaty_symbols_file_top100.txt) | ok |
| `raster-hillshade-heatmap-raster-dem` | `--//:enable_layer_raster=false --//:enable_layer_hillshade=false --//:enable_layer_heatmap=false --//:enable_layer_color_relief=false --//:enable_layer_raster_dem=false` | 15109104 | -787448 | -4.95% | 6036712 | 266736 | 4.23% | 11534861 | [bloaty_symbols_file_top100.txt](ios-layer-size-reports/20260604-213905/raster-hillshade-heatmap-raster-dem/bloaty_symbols_file_top100.txt) | ok |
| `symbol` | `--//:enable_layer_symbol=false` | 14772056 | -1124496 | -7.07% | 5939416 | 364032 | 5.78% | 11375613 | [bloaty_symbols_file_top100.txt](ios-layer-size-reports/20260604-213905/symbol/bloaty_symbols_file_top100.txt) | ok |

## Largest Device Binary Deltas

| Variant | Delta bytes | Delta % | Diff report | Highlight |
|---|---:|---:|---|---|
| `symbol` | -1124496 | -7.07% | [bloaty_diff_vs_baseline_top50.txt](ios-layer-size-reports/20260604-213905/symbol/bloaty_diff_vs_baseline_top50.txt) | Largest cut; diff shows deleted symbol style/render paths, large property-evaluation reductions, and broad `__LINKEDIT`/small-symbol savings. |
| `raster-hillshade-heatmap-raster-dem` | -787448 | -4.95% | [bloaty_diff_vs_baseline_top50.txt](ios-layer-size-reports/20260604-213905/raster-hillshade-heatmap-raster-dem/bloaty_diff_vs_baseline_top50.txt) | Combined raster/DEM stack cut. Also disables color-relief because it is DEM-backed and otherwise keeps shared DEM bucket/render code reachable. |
| `raster` | -265600 | -1.67% | [bloaty_diff_vs_baseline_top50.txt](ios-layer-size-reports/20260604-213905/raster/bloaty_diff_vs_baseline_top50.txt) | Deletes raster layer/image-source entrypoints such as `RenderRasterLayer::update`, `RasterLayerTweaker::execute`, and `RenderImageSource::update`; DEM stays in. |
| `line` | -258424 | -1.63% | [bloaty_diff_vs_baseline_top50.txt](ios-layer-size-reports/20260604-213905/line/bloaty_diff_vs_baseline_top50.txt) | Deletes `RenderLineLayer::update` and `LineLayerTweaker::execute`; shared line bucket/property code remains for fill outlines. |
| `hillshade` | -248048 | -1.56% | [bloaty_diff_vs_baseline_top50.txt](ios-layer-size-reports/20260604-213905/hillshade/bloaty_diff_vs_baseline_top50.txt) | Deletes `RenderHillshadeLayer::update` and `HillshadeLayerTweaker::execute`; raster-dem infrastructure remains available. |
| `circle` | -242128 | -1.52% | [bloaty_diff_vs_baseline_top50.txt](ios-layer-size-reports/20260604-213905/circle/bloaty_diff_vs_baseline_top50.txt) | Deletes `RenderCircleLayer::update` and `CircleLayerTweaker::execute`; most remaining savings are distributed across property helpers and link metadata. |
| `fill` | -193640 | -1.22% | [bloaty_diff_vs_baseline_top50.txt](ios-layer-size-reports/20260604-213905/fill/bloaty_diff_vs_baseline_top50.txt) | Deletes `RenderFillLayer::update` and fill tweaker/annotation paths; shared pattern/layout helpers still appear because other layers use them. |
| `fill-extrusion` | -188288 | -1.18% | [bloaty_diff_vs_baseline_top50.txt](ios-layer-size-reports/20260604-213905/fill-extrusion/bloaty_diff_vs_baseline_top50.txt) | Deletes `RenderFillExtrusionLayer::update`, fill-extrusion bucket/property code, and related ObjC layer additions. |

## Notes

- Device binary path is selected from the extracted `ios-arm64` XCFramework slice.
- Stripped metrics use `xcrun strip -x` on a copied device binary, so local symbols are removed while exported dynamic-library symbols are preserved.
- Bloaty symbol reports run with the matching device dSYM from Bazel output.
- Diff reports compare each disabled variant against baseline with Bloaty file-domain symbol grouping.
- `symbol` keeps shared placement/query infrastructure compiled in this pass; its row should be read as wrapper/registration impact, not complete symbol-renderer removal.
- `line` keeps shared line style/bucket pieces used by fill outlines; its row should be read as render layer/API removal plus reachable-code fallout.
- `raster` removes `MLNImageSource.h` and `MLNRasterStyleLayer.h`; `MLNRasterTileSource.h` remains because `MLNRasterDEMSource` inherits from it.
- `raster` keeps raster-dem base classes compiled so terrain/raster-dem remains available.
- The combined raster/raster-dem stack row also disables `color-relief`, because color-relief is backed by raster-dem tiles.
- Metal shader source selection is conservative in this pass, so shader-related deltas may understate the theoretical layer-only savings.
- CMake now has `MLN_WITH_LAYER_RASTER_DEM`; this report still uses Bazel source-list filtering for the measured iOS XCFramework.
