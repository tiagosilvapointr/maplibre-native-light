#pragma once

#include <mbgl/style/conversion.hpp>
#include <mbgl/util/tileset.hpp>

#include <optional>

namespace mbgl {
namespace style {

struct SourceOptions {
    std::optional<Tileset::RasterEncoding> rasterEncoding = std::nullopt;
    std::optional<Tileset::VectorEncoding> vectorEncoding = std::nullopt;
};

namespace conversion {

template <>
struct Converter<SourceOptions> {
    std::optional<SourceOptions> operator()(const Convertible& value, Error& error) const;
};

} // namespace conversion
} // namespace style
} // namespace mbgl
