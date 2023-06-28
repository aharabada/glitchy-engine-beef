#pragma EngineBuffer[ Name = "SceneConstants"; Binding = "Scene" ]
cbuffer SceneConstants : register(b0)
{
    float4x4 ViewProjection;
}

#pragma EngineBuffer[ Name = "ObjectConstants"; Binding = "Object" ]
cbuffer ObjectConstants : register(b1)
{
    float4x4 Transform;
    /**
     * \brief Inverted and transposed transform matrix.
     * \remarks This matrix is used in order to correctly transform normal vectors.
     */
    float4x3 Transform_InvT;
#ifdef OutputEntityId
    uint EntityId;
#endif
}

/**
 * \brief Pixel Shader output for lit surfaces.
 */
struct PS_OUT_Lit
{
    /** RGB: Albedo A: Transparency */
    float4 Albedo : SV_TARGET0;
    /** RG: TextureNormal.XY | BA: GeoNrm.XY */
    float4 Normal : SV_TARGET1;
    /** R: GeoNrm.Z | GBA: GeoTan.XYZ */
    float4 Tangent : SV_TARGET2;
    /** RGB: world position XYZ | A: 1.0 */
    float4 Position : SV_TARGET3;
    /** RGB: emissive light and color | A: unused */
    float4 Emissive : SV_TARGET4;
    /** R: Metallicity | G: Roughness | B: Ambient | A: Unused */
    float4 Material : SV_TARGET5;
#ifdef OutputEntityId
    /** Needed for editor picking. Simply pass through the EntityId. */
    uint EntityId : SV_TARGET6;
#endif
};

/**
 * \brief Pixel Shader output for unlit surfaces.
 */
struct PS_OUT_Unlit
{
    /** RGB: Color A: Transparency */
    float4 Color : SV_TARGET0;
    /** RGB: emissive light and color | A: unused */
    float4 Emissive : SV_TARGET1;
    /** RGB: world position XYZ | A: 1.0 */
    float4 Position : SV_TARGET2;

#ifdef OutputEntityId
    uint EntityId : SV_TARGET5;
#endif
};
