#pragma EngineBuffer[ Name = "SceneConstants"; Binding = "Scene" ]
/**
 * Contains constants that apply to the current scene.
 */
cbuffer SceneConstants : register(b0)
{
    /**
     * View projection matrix of the active camera.
     */
    float4x4 ViewProjection;
}

/**
 * Contains the data provided by the engine for a 2D vertex shader.
 */
struct VS_Input
{
    // Geometry
    
    /**
     * Vertex position
     */
    float2 Position     : POSITION;
    /**
     * Vertex texture coordinate
     */
    float2 Texcoord     : TEXCOORD0;

    // Instance data
    /**
     * model to world transform matrix of the current quad.
     */
    float4x4 Transform  : TRANSFORM;
    /**
     * Color of the current quad.
     */
    float4 Color        : COLOR;
    /**
     * model to world transform matrix of the current quad.
     */
    float4 UVTransform  : TEXCOORD1;
#ifdef EDITOR
    /**
     * The ECS ID of the entity associated with the current quad.
     */
    uint EntityId : ENTITYID;
#endif
};

/**
 * Contains the output data of the vertex shader that will be passed into the pixel shader.
 */
typedef struct PS_Input
{
    /**
     * The screen space position of the current vertex.
     */
    float4 Position : SV_Position;
    /**
     * The transformed texture coordinates of the current vertex.
     */
    float2 Texcoord : TEXCOORD;
    /**
     * The color of the current vertex.
     */
    float4 Color    : COLOR;
#ifdef EDITOR
    /**
     * The ECS ID of the entity associated with the current quad.
     * This should always just be passed through.
     */
    nointerpolation uint EntityId : ENTITYID;
#endif
} VS_Output;
