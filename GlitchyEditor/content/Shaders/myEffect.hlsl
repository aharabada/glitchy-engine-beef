#include "ShaderHelpers.hlsl"

Texture2D AlbedoTexture : register(t0);
SamplerState AlbedoSampler : register(s0);

Texture2D<float3> NormalTexture : register(t1);
SamplerState NormalSampler : register(s1);

Texture2D<float> MetallicTexture : register(t2);
SamplerState MetallicSampler : register(s2);

Texture2D<float> RoughnessTexture : register(t3);
SamplerState RoughnessSampler : register(s3);

// Texture2D<float> AmbientTexture : register(t4);
// SamplerState AmbientSampler : register(s4);

cbuffer SceneConstants
{
    float4x4 ViewProjection;
}

cbuffer ObjectConstants
{
    float4x4 Transform;
}

cbuffer Constants
{
    float4 AlbedoColor = float4(1.0, 1.0, 1.0, 1.0);
    float2 NormalScaling = float2(1.0, 1.0);
    float MetallicFactor = 1.0;
    float RoughnessFactor = 1.0;
    // float AmbientFactor = 1.0;
}

struct VS_IN
{
    float3 Position     : POSITION;
    float3 Normal       : NORMAL;
    // Todo: Tangent.w... handedness
	float3 Tangent      : TANGENT;
	float2 TexCoord     : TEXCOORD;
};

struct PS_IN
{
    float4 Position      : SV_POSITION;
    float3 WorldPosition : WORLDPOSITION;
    float3 Normal        : NORMAL;
	float3 Tangent       : TANGENT;
	float2 TexCoord      : TEXCOORD;
	//nointerpolation float Handedness : HANDEDNESS;
};

PS_IN VS(VS_IN input)
{
    PS_IN output;
	
	float4 worldPosition = mul(Transform, float4(input.Position, 1));
	
	output.Position = mul(ViewProjection, worldPosition);
    output.WorldPosition = worldPosition.xyz / worldPosition.w;

	output.Normal = mul(input.Normal, (float3x3)Transform);
	output.Tangent = mul((float3x3)Transform, input.Tangent);
	// TODO: output.Handedness = input.Tangent.w

	output.TexCoord = input.TexCoord;
    
    return output;
}

struct PS_OUT
{
    float4 Albedo   : SV_TARGET0;
    // RG: TextureNormal.XY BA: GeoNrm.XY
    float4 Normal   : SV_TARGET1;
    // R: GeoNrm.Z GBA: GeoTan.XYZ
    float4 Tangent   : SV_TARGET2;
    float4 Position : SV_TARGET3;
    // R: Metallicity G: Roughness B: Ambient
    float4 Material : SV_TARGET4;
};

PS_OUT PS(PS_IN input)
{
    // Build tangent space
    float3 normal = normalize(input.Normal);
    float3 tangent = normalize(input.Tangent - dot(input.Tangent, normal) * input.Normal);
    // TODO: float3 bitangent = input.Handedness * cross(normal, tangent);
    float3 bitangent = -cross(normal, tangent);

    float3x3 tangentTransform = float3x3(tangent, bitangent, normal);
    //tangentTransform = transpose(tangentTransform);

    float4 texAlbedo = AlbedoTexture.Sample(AlbedoSampler, input.TexCoord);
    float3 texNormal = NormalTexture.Sample(NormalSampler, input.TexCoord);
    texNormal.xy = texNormal.xy * 2.0 - 1.0;
    float texMetallic = MetallicTexture.Sample(MetallicSampler, input.TexCoord);
    float texRoughness = RoughnessTexture.Sample(RoughnessSampler, input.TexCoord);

    //float3 objectNormal = mul(tangentTransform, texNormal);
    //float3 worldNormal = mul(objectNormal, (float3x3)Transform);

    float4 finalAlbedo = texAlbedo * AlbedoColor;
    float3 finalNormal = ScaleNormal(texNormal, NormalScaling);
    float finalMetallic = texMetallic * MetallicFactor;
    float finalRoughness = texRoughness * RoughnessFactor;

/////////////TODO: REMOVEME

	//worldNormal = max(worldNormal - 10000000, normal);
	//texAlbedo = max(texAlbedo - 10000000, 1.0);
	//texMetallic = max(texMetallic - 10000000, 0.0);
	//texRoughness = max(texRoughness - 10000000, 0.1);

/////////////TODO: END_REMOVEME

    PS_OUT output;
    output.Albedo = finalAlbedo;
    //output.Normal = float4(objectNormal, 1.0);
    output.Normal = float4(finalNormal.xy, normal.xy);
    output.Tangent = float4(normal.z, tangent.xyz);
	output.Position = float4(input.WorldPosition, 1.0); 
    output.Material = float4(finalMetallic, finalRoughness, 1.0, 0);

    return output;
}

#effect[VS=VS,PS=PS]