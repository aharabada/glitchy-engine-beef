#include "ShaderFunctions.hlsl"

#define PI 3.14159265358979323846f

SamplerState Sampler : register(s0);

Texture2D GBuffer_Albedo : register(t0);
Texture2D GBuffer_Normal : register(t1);
Texture2D GBuffer_Tangent : register(t2);
Texture2D GBuffer_Position : register(t3);
Texture2D GBuffer_Material : register(t4);

cbuffer Constants
{
	float3 LightColor;
    float Illuminance;
    float3 LightDir;

    float3 CameraPos;

	float2 Scaling;
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

/**
 * Normal Distribution Function. (Trowbridge-Reits GGX)
 * Calculates the relative surface area of microfacets exactly aligned to the halfway vector.
 * @param normal The surface normal.
 * @param halfway The halfway vector between the surface normal and the view direction.
 * @param roughness Roughness value.
 * @returns The relative surface area of microfacets exactly aligned to the halfway vector.
 */
float NormalDistributionGGX(float3 normal, float3 halfway, float roughness)
{
	// Square roughness because it looks better
	float a = roughness * roughness;
	float aa = a * a;

	float n_dot_h = max(dot(normal, halfway), 0.0f);

	float denom = (n_dot_h * n_dot_h) * (aa - 1.0f) + 1.0f;
	denom = PI * denom * denom;

	return aa / denom;
}

/**
 * Geometry Function calculating the overshadowing of microfacets based on roughness. (Schlick-Beckmann GGX).
 * @param dot-product of normal vector and vector from surface to camera.
 * @param k Roughness value.
 */
float GeometrySchlickGGX(float n_dot_v, float k)
{
	return n_dot_v / (n_dot_v * (1 - k) + k);
}

/**
 * Geometry Function calculating the overshadowing of microfacets based on roughness. (Smith)
 * @param normal The surface normal.
 * @param viewDir Vector from surface to viewer.
 * @param lightDir Vector from surface to light source.
 * @param roughness Roughness value.
 */
float GeometrySmith(float3 normal, float3 viewDir, float3 lightDir, float roughness)
{
	// Direct lighting
	float k = (roughness + 1.0f);
	k = (k * k) / 8;
	
	// IBL
	// float k = alpha * alpha / 2

	float n_dot_v = max(dot(normal, viewDir), 0.0f);
	float n_dot_l = max(dot(normal, lightDir), 0.0f);

	return GeometrySchlickGGX(n_dot_v, k) * GeometrySchlickGGX(n_dot_l, k);
}

/**
 * Calculates the fresnel value.
 * @param h_dot_v Dot product of the normal and view direction
 * @param F0 base reflectivity
 */
float3 FresnelSchlick(float cosTheta, float3 F0)
{
	return F0 + (1.0f - F0) * pow(clamp(1.0f - cosTheta, 0.0f, 1.0f), 5.0f);
}

/*
* Reconstructs the z-component of a normalized normal vector from a two-component value
* cnrm: The x- and y-components of a normalized normal vector
*/
//float3 DecompressNormal(float2 cnrm)
//{
//	return float3(cnrm, sqrt(1.0 - cnrm.x * cnrm.x - cnrm.y * cnrm.y));
//}

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
	float n_dot_l = max(dot(surfaceNormal, lightDir), 0.0f);

	float nrmDist = NormalDistributionGGX(surfaceNormal, halfway, roughness);
	float geo = GeometrySmith(surfaceNormal, viewDir, lightDir, roughness);

	float3 F0 = 0.04f;
	F0 = lerp(F0, albedo, metallic);
	float3 fresnel = FresnelSchlick(n_dot_v, F0);

	// if (InspectNrmDist)
	// 	return float4(nrmDist.xxx, 1);
	// else if (InspectGeo)
	// 	return float4(geo.xxx, 1);
	// else if (InspectFresnel)
	// 	return float4(fresnel, 1);
	// else if (CookTorrance)
	// {
		float3 ks = fresnel;
		float3 kd = 1.0f - ks;

		// Metals have no diffuse light
		kd *= 1.0f - metallic;

		float3 diffuse = albedo / PI;
		float3 specular = (nrmDist * fresnel * geo) / max(4 * n_dot_v * n_dot_l, 0.0001f);

		float3 luminanceColor = LightColor * Illuminance;

		float3 cook = (kd * diffuse + specular) * luminanceColor * n_dot_l;

		float3 final = cook;

		// Tone mapping	// TODO: do in postprocessing
		final = final / (final + 1.0f);

		// Gamma correction // TODO: do in postprocessing/hardware
		final = pow(final, 1.0f / 2.2f);

/////////////TODO: REMOVEME

		//final = max(final - 10000000, nrmDist.xxx);
		//final = max(final - 10000000, geo.xxx);
		//final = max(final - 10000000, fresnel);
		//final = max(final - 10000000, surfaceNormal / 2 + 0.5f);
		//final = max(final - 10000000, abs(normal - surfaceNormal) / 2 + 0.5f);

/////////////TODO: END_REMOVEME

		return float4(final, 1);
	//}
}

#effect[VS=VS,PS=PS]
