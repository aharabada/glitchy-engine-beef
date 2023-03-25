#include "ShaderHelpers.hlsl"
#include "PBR.hlsl"

#define Render						0
#define Inspect_NormalDistribution	1
#define Inspect_GeometryFunction	2
#define Inspect_Fresnel				3
#define Inspect_Normal				4

#define OUTPUT Render

SamplerState Sampler : register(s0);

Texture2D GBuffer_Albedo : register(t0);
Texture2D GBuffer_Normal : register(t1);
Texture2D GBuffer_Tangent : register(t2);
Texture2D GBuffer_Position : register(t3);
Texture2D GBuffer_Material : register(t4);

cbuffer Constants
{
	float3 CameraPos;
	float2 Scaling;
}

cbuffer LightConstants
{
	float3 LightColor;
    float Illuminance;
    float3 LightDir;
}

struct VS_IN
{
    float2 Position : POSITION;
    float2 TexCoord : TEXCOORD0;
};

struct PS_IN
{
    float4 Position : SV_POSITION;
    float2 TexCoord : TEXCOORD;
};

PS_IN VS(VS_IN input)
{
    PS_IN output;
	
    output.Position = float4(input.Position, 0, 1);
    output.TexCoord = input.TexCoord * Scaling;
    
    return output;
}

float4 PS(PS_IN input) : SV_TARGET
{
    // Load Data from GBuffer
    float4 rawAlbedo = GBuffer_Albedo.Sample(Sampler, input.TexCoord);
	float4 rawNormal = GBuffer_Normal.Sample(Sampler, input.TexCoord);
	float4 rawTangent = GBuffer_Tangent.Sample(Sampler, input.TexCoord);
	float4 rawPosition = GBuffer_Position.Sample(Sampler, input.TexCoord);
	float4 rawMaterial = GBuffer_Material.Sample(Sampler, input.TexCoord);

	// Extract data from GBuffer
	float3 albedo = rawAlbedo.rgb;
    //float3 surfaceNormal = normalize(rawNormal.xyz);
    float3 worldPosition = rawPosition.xyz;

    float metallic = rawMaterial.r;
    float roughness = rawMaterial.g;

	float3 textureNormal = DecompressNormal(rawNormal.rg);
	float3 rawGeoNrm = float3(rawNormal.ba, rawTangent.r);
	float3 rawGeoTan = rawTangent.gba;

	// Reconstruct normal space
	float3 normal = normalize(rawGeoNrm);
	float3 tangent = normalize(rawGeoTan - dot(rawGeoTan, normal) * normal);
	float3 bitangent = -cross(normal, tangent);

	float3x3 tangentTransform = float3x3(tangent, bitangent, normal);

	float3 surfaceNormal = mul(textureNormal, tangentTransform);
	
	float3 lightDir = normalize(LightDir);
	float3 viewDir = normalize(CameraPos - worldPosition.xyz);
	float3 halfway = normalize(lightDir + viewDir);

	float n_dot_v = max(dot(surfaceNormal, viewDir), 0.0f);
	float n_dot_h = max(dot(surfaceNormal, halfway), 0.0f);
	float n_dot_l = max(dot(surfaceNormal, lightDir), 0.0f);

	float nrmDist = NormalDistributionGGX(surfaceNormal, halfway, roughness);
	float geo = GeometrySmith(surfaceNormal, viewDir, lightDir, roughness);

	float3 F0 = 0.04f;
	F0 = lerp(F0, albedo, metallic);
	float3 fresnel = FresnelSchlick(n_dot_h, F0);
	
	float3 ks = fresnel;
	float3 kd = 1.0f - ks;

	// Metals have no diffuse light
	kd *= 1.0f - metallic;

	float3 diffuse = albedo / PI;
	float3 specular = (nrmDist * fresnel * geo) / max(4 * n_dot_v * n_dot_l, 0.0001f);

	float3 luminanceColor = LightColor * Illuminance;

	float3 final = (kd * diffuse + specular) * luminanceColor * n_dot_l;
	
#if OUTPUT == Inspect_NormalDistribution
		final = max(final - 10000000, nrmDist.xxx);
#elif OUTPUT == Inspect_GeometryFunction
		final = max(final - 10000000, geo.xxx);
#elif OUTPUT == Inspect_Fresnel
		final = max(final - 10000000, fresnel);
#elif OUTPUT == Inspect_Normal
		final = max(final - 10000000, surfaceNormal / 2 + 0.5f);
#endif

	return float4(final, 1);
}

#pragma Effect[VS = VS; PS = PS]
