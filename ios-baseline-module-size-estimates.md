# iOS Baseline Module Size Estimates

Generated: 2026-06-05

Baseline input:

- Device binary: `ios-layer-size-reports/20260604-213905/baseline/extract/MapLibre.xcframework/ios-arm64/MapLibre.framework/MapLibre`
- Baseline Bloaty report: `ios-layer-size-reports/20260604-213905/baseline/bloaty_symbols_file_all.txt`
- Stripped binary: `ios-layer-size-reports/20260604-213905/baseline/MapLibre.stripped`
- C string export: `ios-cstring-section-baseline.tsv`
- Existing layer variant summary: `ios-layer-size-impact.md`

## Scope And Confidence

The original baseline Bloaty report is symbol-domain, not compile-unit-domain. That means these are estimates, not exact object-file ownership numbers. The original dSYM used for the Bloaty run was not retained in the report directory, so compile-unit attribution could not be regenerated.

Two symbol estimates are shown:

- Direct symbol bytes: rows directly identifiable in the existing short-demangled baseline report.
- Template-inclusive estimate: same baseline binary, rerun with full demangling to catch template instantiations whose full signatures mention the module. This is useful for C++ units like MLT, style expressions, and PMTiles, but it can over-attribute generic `std` template code to the module appearing in the signature.

For feature flags that already have built variants, the measured stripped delta is more reliable than symbol grouping.

## Baseline Binary

| Item | Bytes | MiB | Notes |
|---|---:|---:|---|
| Unstripped baseline framework binary | 15,896,552 | 15.16 | CI-style analysis binary with symbols retained |
| Stripped baseline framework binary | 6,303,448 | 6.01 | Produced with `xcrun strip -x` |
| `__LINKEDIT` in unstripped binary | 10,014,696 | 9.55 | Mostly symbol/string metadata, not runtime code |
| Non-`__LINKEDIT` unstripped payload | 5,881,856 | 5.61 | Code/data/resources before remaining stripped linker metadata |

Largest `__LINKEDIT` components from Bloaty `segments,sections`:

| Component | Bytes | MiB |
|---|---:|---:|
| String Table | 6,081,112 | 5.80 |
| Symbol Table | 3,735,200 | 3.56 |
| Export Info | 104,008 | 0.10 |
| Function Start Addresses | 50,288 | 0.05 |
| Binding/Rebase/Lazy/Indirect/Weak metadata | 44,088 | 0.04 |

## Module Estimates

| Unit / module | Direct symbol bytes | Template-inclusive estimate | Notes |
|---|---:|---:|---|
| Style, expression, and property system | 530,072 | 2,438,230 | Large template surface; high estimate includes `std` instantiations with style/property types |
| Darwin/iOS ObjC API and wrappers | 842,563 | 1,269,969 | ObjC API, wrappers, `MLNStyleValueTransformer`, `NSExpression` additions |
| Metal renderer and shader pipeline | 283,501 | 1,038,073 | Does not include all shader source strings; see `__cstring` section below |
| Symbol/text placement and glyph management | 190,796 | 807,869 | Bloaty grouping only; measured symbol-layer stripped delta is 364,032 bytes |
| Geometry, vector tile, and clipping libs | 192,844 | 790,217 | MVT, feature index, geojson-vt, Wagyu/Boost.Geometry-style symbols |
| FreeType font rasterization | 363,328 | 417,430 | Removed when HarfBuzz text shaping is disabled |
| HarfBuzz text shaping | 159,437 | 301,315 | Removed by `--//:shaping=legacy` / `MLN_TEXT_SHAPING_HARFBUZZ=OFF` |
| ICU / Unicode bidi data | 169,799 | 179,708 | Bidi/unicode tables and functions; not clearly tied only to HarfBuzz |
| Storage, networking, offline | 118,371 | 519,426 | HTTP, file source, resource loading, offline-ish symbols |
| Core map/render orchestration and actors | 185,375 | 261,600 | Actor/message/render orchestration symbols directly identified |
| MLT decoder and VectorMLT bridge | 49,015 | 157,341 | No top-level flag exists yet; this is symbol-based only |
| PMTiles | 23,737 | 117,885 | Symbol-based estimate; CMake has `MLN_WITH_PMTILES`, Bazel appears always linked |

## HarfBuzz Estimate

The HarfBuzz feature switch removes both HarfBuzz and FreeType implementation/library code:

| Bucket | Direct symbol bytes | Template-inclusive estimate |
|---|---:|---:|
| HarfBuzz | 159,437 | 301,315 |
| FreeType | 363,328 | 417,430 |
| Combined likely flag impact before link metadata | 522,765 | 718,745 |

`ICU / Unicode bidi data` is shown separately because it is not clearly owned only by the HarfBuzz switch. If it stayed linked, the HarfBuzz-off size win would likely be closer to the combined HarfBuzz+FreeType range above. If related Unicode tables were also made optional, the upper opportunity would be roughly another 170-180 KB.

## MLT Estimate

MLT has no maintained top-level feature flag in this tree yet.

| Bucket | Bytes |
|---|---:|
| Direct MLT symbols in existing baseline report | 49,015 |
| Template-inclusive MLT estimate | 157,341 |
| MLT strings in `__cstring` | 204 |

This likely understates the final impact of a real `MLN_WITH_MLT` / `--//:enable_mlt=false` flag, because removing the dependency could also remove vendor-level helpers and generic template instantiations that do not preserve `mlt` in the shortened symbol name.

## `__cstring` Split

Bloaty reports `__TEXT,__cstring` as one section row. The exported baseline cstring table gives this split:

| C string bucket | Bytes | Count |
|---|---:|---:|
| Total string payload | 332,615 | 5,258 strings |
| Shader-like source strings | 197,011 | 57 strings |
| ObjC/API-ish strings | 17,986 | n/a |
| MLT-related strings | 204 | n/a |
| Other cstrings | 117,414 | n/a |

The largest cstrings are embedded shader/source strings, not symbols. Shader-like cstrings should be considered part of the Metal/shader footprint, so that module is roughly 480 KB direct or 1.24 MB template-inclusive if shader source strings are added.

## Existing Measured Layer Deltas

These are from existing one-flag-off builds and are more reliable than symbol grouping for layer code because they measure the actual final device framework binary.

| Disabled variant | Unstripped saved bytes | Stripped saved bytes | Stripped saved % |
|---|---:|---:|---:|
| `symbol` | 1,124,496 | 364,032 | 5.78% |
| `raster-hillshade-heatmap-raster-dem` | 787,448 | 266,736 | 4.23% |
| `raster` | 265,600 | 99,728 | 1.58% |
| `hillshade` | 248,048 | 99,344 | 1.58% |
| `line` | 258,424 | 99,312 | 1.58% |
| `circle` | 242,128 | 99,256 | 1.57% |
| `fill` | 193,640 | 82,776 | 1.31% |
| `fill-extrusion` | 188,288 | 82,744 | 1.31% |
| `plugin` | 108,656 | 50,240 | 0.80% |
| `heatmap` | 107,360 | 33,424 | 0.53% |

## Practical Takeaways

1. The largest unstripped item is `__LINKEDIT`, especially the string and symbol tables. This is analysis-build metadata and mostly disappears under `strip -x`.
2. The largest maintained runtime feature opportunity already measured is the symbol layer: 364,032 stripped bytes.
3. HarfBuzz+FreeType is probably a 0.5-0.7 MB stripped code/data opportunity before considering secondary linker effects. It already has build switches: `--//:shaping=legacy` and `MLN_TEXT_SHAPING_HARFBUZZ=OFF`.
4. MLT looks much smaller by symbols, roughly 49-157 KB, but it needs a real feature flag before the size impact can be measured reliably.
5. Embedded shader source strings are a visible `__cstring` cost: about 197 KB of string payload in the baseline.
