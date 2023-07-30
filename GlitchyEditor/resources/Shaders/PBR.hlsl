/*
 * This File contains Function for PBR.
 */

#ifndef __PBR_HLSL__
#define __PBR_HLSL__

#include "ShaderHelpers.hlsl"

// #define PBR_IBL

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
#ifdef PBR_IBL
	// IBL
	float k = roughness * roughness / 2;
#else
	// Direct lighting
	float k = (roughness + 1.0f);
	k = (k * k) / 8;
#endif

	const float n_dot_v = max(dot(normal, viewDir), 0.0f);
	float n_dot_l = max(dot(normal, lightDir), 0.0f);

	return GeometrySchlickGGX(n_dot_v, k) * GeometrySchlickGGX(n_dot_l, k);
}

/**
 * Calculates the fresnel value.
 * @param n_dot_v Dot product of the normal and view direction
 * @param F0 base reflectivity.
 */
float3 FresnelSchlick(float n_dot_v, float3 F0)
{
	return F0 + (1.0 - F0) * pow(clamp(1.0 - n_dot_v, 0.0, 1.0), 5.0);
}

#endif // __PBR_HLSL__
