#!/usr/bin/env bash
set -u -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_ROOT="${REPORT_ROOT:-ios-layer-size-reports}"
SUMMARY_FILE="${SUMMARY_FILE:-ios-layer-size-impact.md}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
REPORT_DIR="${ROOT_DIR}/${REPORT_ROOT}/${RUN_ID}"
BLOATY="${BLOATY:-}"

BAZEL_ARGS=(
  build
  //platform/ios:MapLibre.dynamic
  --//:renderer=metal
  --compilation_mode=opt
  --copt
  -g
  --copt=-Oz
  --strip
  never
  --output_groups=+dsyms
  --apple_generate_dsym
)

LAYERS=(
  "baseline:"
  "background:--//:enable_layer_background=false"
  "circle:--//:enable_layer_circle=false"
  "color-relief:--//:enable_layer_color_relief=false"
  "custom:--//:enable_layer_custom=false"
  "custom-drawable:--//:enable_layer_custom_drawable=false"
  "fill:--//:enable_layer_fill=false"
  "fill-extrusion:--//:enable_layer_fill_extrusion=false"
  "heatmap:--//:enable_layer_heatmap=false"
  "hillshade:--//:enable_layer_hillshade=false"
  "line:--//:enable_layer_line=false"
  "location-indicator:--//:enable_layer_location_indicator=false"
  "plugin:--//:enable_layer_plugin=false"
  "raster:--//:enable_layer_raster=false"
  "raster-hillshade-heatmap-raster-dem:--//:enable_layer_raster=false --//:enable_layer_hillshade=false --//:enable_layer_heatmap=false --//:enable_layer_color_relief=false --//:enable_layer_raster_dem=false"
  "symbol:--//:enable_layer_symbol=false"
)

find_bloaty() {
  if [[ -n "${BLOATY}" && -x "${BLOATY}" ]]; then
    printf '%s\n' "${BLOATY}"
    return 0
  fi
  if [[ -x "${ROOT_DIR}/bloaty/build-mixed/bloaty" ]]; then
    printf '%s\n' "${ROOT_DIR}/bloaty/build-mixed/bloaty"
    return 0
  fi
  if [[ -x "${ROOT_DIR}/bloaty/build/bloaty" ]]; then
    printf '%s\n' "${ROOT_DIR}/bloaty/build/bloaty"
    return 0
  fi
  if command -v bloaty >/dev/null 2>&1; then
    command -v bloaty
    return 0
  fi
  if [[ -f "${ROOT_DIR}/bloaty/CMakeLists.txt" ]]; then
    cmake -S "${ROOT_DIR}/bloaty" -B "${ROOT_DIR}/bloaty/build" -DCMAKE_BUILD_TYPE=Release
    cmake --build "${ROOT_DIR}/bloaty/build" --target bloaty --config Release
    printf '%s\n' "${ROOT_DIR}/bloaty/build/bloaty"
    return 0
  fi
  git clone https://github.com/google/bloaty.git "${ROOT_DIR}/bloaty"
  cmake -S "${ROOT_DIR}/bloaty" -B "${ROOT_DIR}/bloaty/build" -DCMAKE_BUILD_TYPE=Release
  cmake --build "${ROOT_DIR}/bloaty/build" --target bloaty --config Release
  printf '%s\n' "${ROOT_DIR}/bloaty/build/bloaty"
}

file_size() {
  stat -f '%z' "$1"
}

strip_binary() {
  local binary="$1"
  local stripped_binary="$2"
  xcrun strip -x -o "${stripped_binary}" "${binary}"
}

format_delta_percent() {
  local delta="$1"
  local baseline="$2"
  awk -v d="${delta}" -v b="${baseline}" 'BEGIN { if (b == 0) print "n/a"; else printf "%.2f%%", (d / b) * 100 }'
}

extract_device_binary() {
  local zip_path="$1"
  local out_dir="$2"
  mkdir -p "${out_dir}/extract"
  unzip -q -o "${zip_path}" -d "${out_dir}/extract"
  local exact="${out_dir}/extract/MapLibre.xcframework/ios-arm64/MapLibre.framework/MapLibre"
  if [[ -f "${exact}" ]]; then
    printf '%s\n' "${exact}"
    return 0
  fi
  find "${out_dir}/extract" -path '*/ios-arm64/MapLibre.framework/MapLibre' -type f | head -n 1
}

find_device_dsym() {
  find "${ROOT_DIR}/bazel-bin/platform/ios" \
    -path '*MapLibre*dSYM/Contents/Resources/DWARF/*' \
    -type f | grep -E 'device|ios-arm64|MapLibre$' | head -n 1
}

write_summary_header() {
  local summary_path="$1"
  {
    printf '# iOS Layer Size Impact\n\n'
    printf 'Generated: %s\n\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    printf 'Target: `//platform/ios:MapLibre.dynamic`\n\n'
    printf 'Renderer: `metal`\n\n'
    printf 'Reports: [`%s/%s`](%s/%s)\n\n' "${REPORT_ROOT}" "${RUN_ID}" "${REPORT_ROOT}" "${RUN_ID}"
    printf '| Variant | Disabled flag | Device binary bytes | Delta bytes | Delta %% | Stripped binary bytes | Stripped saved bytes | Stripped saved %% | Zip bytes | Bloaty report | Status |\n'
    printf '|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---|\n'
  } > "${summary_path}"
}

append_summary_row() {
  local summary_path="$1"
  local variant="$2"
  local flag="$3"
  local bytes="$4"
  local delta="$5"
  local percent="$6"
  local stripped_bytes="$7"
  local stripped_saved="$8"
  local stripped_percent="$9"
  local zip_bytes="${10}"
  local report_link="${11}"
  local status="${12}"
  printf '| `%s` | `%s` | %s | %s | %s | %s | %s | %s | %s | [%s](%s) | %s |\n' \
    "${variant}" "${flag:-none}" "${bytes}" "${delta}" "${percent}" \
    "${stripped_bytes}" "${stripped_saved}" "${stripped_percent}" "${zip_bytes}" \
    "$(basename "${report_link}")" "${report_link}" "${status}" >> "${summary_path}"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${variant}" "${flag:-none}" "${bytes}" "${delta}" "${percent}" \
    "${stripped_bytes}" "${stripped_saved}" "${stripped_percent}" "${zip_bytes}" \
    "${report_link}" "${status}" >> "${REPORT_DIR}/results.tsv"
}

highlight_for_variant() {
  case "$1" in
    symbol)
      printf '%s\n' 'Largest cut; diff shows deleted symbol style/render paths, large property-evaluation reductions, and broad `__LINKEDIT`/small-symbol savings.'
      ;;
    raster)
      printf '%s\n' 'Deletes raster layer/image-source entrypoints such as `RenderRasterLayer::update`, `RasterLayerTweaker::execute`, and `RenderImageSource::update`; DEM stays in.'
      ;;
    raster-hillshade-heatmap-raster-dem)
      printf '%s\n' 'Combined raster/DEM stack cut. Also disables color-relief because it is DEM-backed and otherwise keeps shared DEM bucket/render code reachable.'
      ;;
    line)
      printf '%s\n' 'Deletes `RenderLineLayer::update` and `LineLayerTweaker::execute`; shared line bucket/property code remains for fill outlines.'
      ;;
    hillshade)
      printf '%s\n' 'Deletes `RenderHillshadeLayer::update` and `HillshadeLayerTweaker::execute`; raster-dem infrastructure remains available.'
      ;;
    circle)
      printf '%s\n' 'Deletes `RenderCircleLayer::update` and `CircleLayerTweaker::execute`; most remaining savings are distributed across property helpers and link metadata.'
      ;;
    fill)
      printf '%s\n' 'Deletes `RenderFillLayer::update` and fill tweaker/annotation paths; shared pattern/layout helpers still appear because other layers use them.'
      ;;
    fill-extrusion)
      printf '%s\n' 'Deletes `RenderFillExtrusionLayer::update`, fill-extrusion bucket/property code, and related ObjC layer additions.'
      ;;
    *)
      printf '%s\n' 'See the linked Bloaty report for the highest file-domain rows.'
      ;;
  esac
}

append_summary_footer() {
  local summary_path="$1"
  {
    printf '\n## Largest Device Binary Deltas\n\n'
    printf '| Variant | Delta bytes | Delta %% | Diff report | Highlight |\n'
    printf '|---|---:|---:|---|---|\n'
  } >> "${summary_path}"

  local line
  while IFS=$'\t' read -r variant flag bytes delta percent stripped_bytes stripped_saved stripped_percent zip_bytes report_link status; do
    if [[ "${variant}" == "baseline" || "${status}" != "ok" || "${delta}" == "n/a" ]]; then
      continue
    fi
    local diff_link="${REPORT_ROOT}/${RUN_ID}/${variant}/bloaty_diff_vs_baseline_top50.txt"
    local link="${diff_link}"
    if [[ ! -f "${ROOT_DIR}/${diff_link}" ]]; then
      link="${report_link}"
    fi
    local highlight
    highlight="$(highlight_for_variant "${variant}")"
    printf '| `%s` | %s | %s | [%s](%s) | %s |\n' \
      "${variant}" "${delta}" "${percent}" "$(basename "${link}")" "${link}" "${highlight}" >> "${summary_path}"
  done < <(
    awk -F '\t' '$11 == "ok" && $1 != "baseline" && $4 ~ /^-/ { print $4 "\t" $0 }' "${REPORT_DIR}/results.tsv" |
      sort -n |
      head -n 7 |
      cut -f2-
  )

  {
    printf '\n## Notes\n\n'
    printf '%s\n' '- Device binary path is selected from the extracted `ios-arm64` XCFramework slice.'
    printf '%s\n' '- Stripped metrics use `xcrun strip -x` on a copied device binary, so local symbols are removed while exported dynamic-library symbols are preserved.'
    printf '%s\n' '- Bloaty symbol reports run with the matching device dSYM from Bazel output.'
    printf '%s\n' '- Diff reports compare each disabled variant against baseline with Bloaty file-domain symbol grouping.'
    printf '%s\n' '- `symbol` keeps shared placement/query infrastructure compiled in this pass; its row should be read as wrapper/registration impact, not complete symbol-renderer removal.'
    printf '%s\n' '- `line` keeps shared line style/bucket pieces used by fill outlines; its row should be read as render layer/API removal plus reachable-code fallout.'
    printf '%s\n' '- `raster` removes `MLNImageSource.h` and `MLNRasterStyleLayer.h`; `MLNRasterTileSource.h` remains because `MLNRasterDEMSource` inherits from it.'
    printf '%s\n' '- `raster` keeps raster-dem base classes compiled so terrain/raster-dem remains available.'
    printf '%s\n' '- The combined raster/raster-dem stack row also disables `color-relief`, because color-relief is backed by raster-dem tiles.'
    printf '%s\n' '- Metal shader source selection is conservative in this pass, so shader-related deltas may understate the theoretical layer-only savings.'
    printf '%s\n' '- CMake now has `MLN_WITH_LAYER_RASTER_DEM`; this report still uses Bazel source-list filtering for the measured iOS XCFramework.'
  } >> "${summary_path}"
}

main() {
  cd "${ROOT_DIR}" || exit 1
  mkdir -p "${REPORT_DIR}"
  : > "${REPORT_DIR}/results.tsv"

  local bloaty_bin
  bloaty_bin="$(find_bloaty)" || exit 1

  local summary_path="${ROOT_DIR}/${SUMMARY_FILE}"
  write_summary_header "${summary_path}"

  local baseline_bytes=""
  local baseline_binary=""
  local baseline_stripped_bytes=""

  for entry in "${LAYERS[@]}"; do
    local variant="${entry%%:*}"
    local flag="${entry#*:}"
    local variant_dir="${REPORT_DIR}/${variant}"
    mkdir -p "${variant_dir}"

    local build_log="${variant_dir}/build.log"
    printf 'Building %s %s\n' "${variant}" "${flag}" | tee "${variant_dir}/status.txt"
    if [[ -n "${flag}" ]]; then
      read -r -a extra_bazel_args <<< "${flag}"
      bazel "${BAZEL_ARGS[@]}" "${extra_bazel_args[@]}" >"${build_log}" 2>&1
    else
      bazel "${BAZEL_ARGS[@]}" >"${build_log}" 2>&1
    fi
    local build_status=$?
    if [[ ${build_status} -ne 0 ]]; then
      append_summary_row "${summary_path}" "${variant}" "${flag}" "n/a" "n/a" "n/a" "n/a" "n/a" "n/a" "n/a" "${REPORT_ROOT}/${RUN_ID}/${variant}/build.log" "build failed"
      continue
    fi

    local zip_path="${ROOT_DIR}/bazel-bin/platform/ios/MapLibre.dynamic.xcframework.zip"
    local zip_bytes
    zip_bytes="$(file_size "${zip_path}")"

    local binary
    binary="$(extract_device_binary "${zip_path}" "${variant_dir}")"
    local dsym
    dsym="$(find_device_dsym)"
    if [[ -z "${binary}" || -z "${dsym}" ]]; then
      append_summary_row "${summary_path}" "${variant}" "${flag}" "n/a" "n/a" "n/a" "n/a" "n/a" "n/a" "${zip_bytes}" "${REPORT_ROOT}/${RUN_ID}/${variant}/build.log" "missing binary or dSYM"
      continue
    fi

    local bytes
    bytes="$(file_size "${binary}")"
    local stripped_binary="${variant_dir}/MapLibre.stripped"
    local stripped_bytes="n/a"
    if strip_binary "${binary}" "${stripped_binary}" >"${variant_dir}/strip.err" 2>&1; then
      stripped_bytes="$(file_size "${stripped_binary}")"
    fi
    if [[ "${variant}" == "baseline" ]]; then
      baseline_bytes="${bytes}"
      baseline_binary="${binary}"
      baseline_stripped_bytes="${stripped_bytes}"
    fi

    local delta="0"
    local percent="0.00%"
    if [[ -n "${baseline_bytes}" ]]; then
      delta=$((bytes - baseline_bytes))
      percent="$(format_delta_percent "${delta}" "${baseline_bytes}")"
    fi

    local stripped_saved="0"
    local stripped_percent="0.00%"
    if [[ "${stripped_bytes}" == "n/a" || -z "${baseline_stripped_bytes}" || "${baseline_stripped_bytes}" == "n/a" ]]; then
      stripped_saved="n/a"
      stripped_percent="n/a"
    else
      stripped_saved=$((baseline_stripped_bytes - stripped_bytes))
      stripped_percent="$(format_delta_percent "${stripped_saved}" "${baseline_stripped_bytes}")"
    fi

    local top_report="${variant_dir}/bloaty_symbols_file_top100.txt"
    local full_report="${variant_dir}/bloaty_symbols_file_all.txt"
    if ! "${bloaty_bin}" -d symbols --domain=file -s file -n 100 --debug-file="${dsym}" "${binary}" >"${top_report}" 2>"${variant_dir}/bloaty_top100.err"; then
      append_summary_row "${summary_path}" "${variant}" "${flag}" "${bytes}" "${delta}" "${percent}" "${stripped_bytes}" "${stripped_saved}" "${stripped_percent}" "${zip_bytes}" "${REPORT_ROOT}/${RUN_ID}/${variant}/bloaty_top100.err" "bloaty failed"
      continue
    fi
    if ! "${bloaty_bin}" -d symbols --domain=file -s file -n 0 --debug-file="${dsym}" "${binary}" >"${full_report}" 2>"${variant_dir}/bloaty_all.err"; then
      append_summary_row "${summary_path}" "${variant}" "${flag}" "${bytes}" "${delta}" "${percent}" "${stripped_bytes}" "${stripped_saved}" "${stripped_percent}" "${zip_bytes}" "${REPORT_ROOT}/${RUN_ID}/${variant}/bloaty_all.err" "bloaty failed"
      continue
    fi
    if [[ "${variant}" != "baseline" && -n "${baseline_binary}" ]]; then
      "${bloaty_bin}" -d symbols --domain=file -s file -n 50 "${binary}" -- "${baseline_binary}" >"${variant_dir}/bloaty_diff_vs_baseline_top50.txt" 2>"${variant_dir}/bloaty_diff_vs_baseline.err" || true
    fi

    append_summary_row "${summary_path}" "${variant}" "${flag}" "${bytes}" "${delta}" "${percent}" "${stripped_bytes}" "${stripped_saved}" "${stripped_percent}" "${zip_bytes}" "${REPORT_ROOT}/${RUN_ID}/${variant}/bloaty_symbols_file_top100.txt" "ok"
  done

  append_summary_footer "${summary_path}"

  printf 'Summary written to %s\n' "${summary_path}"
}

main "$@"
