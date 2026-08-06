#pragma once

#include <mbgl/gfx/vertex_buffer.hpp>
#include <mbgl/gfx/index_buffer.hpp>
#include <mbgl/gfx/renderbuffer.hpp>
#include <mbgl/gfx/shader_registry.hpp>
#include <mbgl/renderer/buckets/raster_bucket.hpp>
#if !defined(MBGL_LAYER_HEATMAP_DISABLE_ALL)
#include <mbgl/renderer/buckets/heatmap_bucket.hpp>
#endif
#if !defined(MBGL_LAYER_FILL_EXTRUSION_DISABLE_ALL)
#include <mbgl/renderer/buckets/fill_extrusion_bucket.hpp>
#endif

#include <string>
#include <optional>

namespace mbgl {
namespace gfx {
class Context;
class UploadPass;
} // namespace gfx

class RenderStaticData {
public:
    RenderStaticData(std::unique_ptr<gfx::ShaderRegistry>&& shaders_);

    void upload(gfx::UploadPass&);

    std::optional<gfx::VertexBuffer<gfx::Vertex<PositionOnlyLayoutAttributes>>> tileVertexBuffer;
    std::optional<gfx::IndexBuffer> quadTriangleIndexBuffer;

    static gfx::VertexVector<gfx::Vertex<PositionOnlyLayoutAttributes>> tileVertices();
    static gfx::VertexVector<RasterLayoutVertex> rasterVertices();
#if !defined(MBGL_LAYER_HEATMAP_DISABLE_ALL)
    static gfx::VertexVector<HeatmapTextureLayoutVertex> heatmapTextureVertices();
#endif
#if !defined(MBGL_LAYER_FILL_EXTRUSION_DISABLE_ALL)
    static gfx::VertexVector<FillExtrusionStaticVertex> fillExtrusionVertices();
#endif

    static gfx::IndexVector<gfx::Triangles> quadTriangleIndices();
    static gfx::IndexVector<gfx::LineStrip> tileLineStripIndices();
#if !defined(MBGL_LAYER_FILL_EXTRUSION_DISABLE_ALL)
    static gfx::IndexVector<gfx::Triangles> fillExtrusionTriangleIndices();
#endif

    static SegmentVector tileTriangleSegments();
    static SegmentVector tileBorderSegments();
    static SegmentVector rasterSegments();
#if !defined(MBGL_LAYER_HEATMAP_DISABLE_ALL)
    static SegmentVector heatmapTextureSegments();
#endif
#if !defined(MBGL_LAYER_FILL_EXTRUSION_DISABLE_ALL)
    static SegmentVector fillExtrusionSegments();
#endif

    std::optional<gfx::Renderbuffer<gfx::RenderbufferPixelType::Depth>> depthRenderbuffer;
    bool has3D = false;
    bool uploaded = false;
    Size backendSize;

    std::unique_ptr<gfx::ShaderRegistry> shaders;

    const SegmentVector clippingMaskSegments;
};

} // namespace mbgl
