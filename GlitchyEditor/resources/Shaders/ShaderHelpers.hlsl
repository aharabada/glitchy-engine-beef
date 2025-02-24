#ifndef __SHADER_HELPERS_HLSL__
#define __SHADER_HELPERS_HLSL__

#define PI 3.14159265358979323846f

/*
* Calculates the weighted sum of two normal vectors.
* nrm1: The first normal vector
* nrm2: The second normal vector
* a: The weight factor for nrm1
* b: The weight factor for nrm2
*/
float3 BlendNormals(float3 nrm1, float3 nrm2, float a, float b)
{    
    return normalize(float3(a * nrm1.x / nrm1.z + b * nrm2.x / nrm2.z, 
         a * nrm1.y / nrm1.z + b * nrm2.y / nrm2.z, 
         1.0f));
}

/*
* Scales a normal vector by a factor where 0 results in the vector (0, 0, 1)
* nrm: The normal vector
* a: The scaling factor
*/
float3 ScaleNormal(float3 nrm1, float a)
{    
    return normalize(float3(a * nrm1.x / nrm1.z, 
         a * nrm1.y / nrm1.z, 
         1.0f));
}

/*
* Scales a normal vector by a factor where 0 results in the vector (0, 0, 1)
* nrm: The normal vector
* a: The scaling factor
*/
float3 ScaleNormal(float3 nrm1, float2 a)
{
    return normalize(float3(a.x * nrm1.x / nrm1.z,
							a.y * nrm1.y / nrm1.z,
							1.0f));
}

/*
* Reconstructs the z-component of a normalized normal vector from a two-component value
* cnrm: The x- and y-components of a normalized normal vector
*/
float3 DecompressNormal(float2 cnrm)
{
    return float3(cnrm, sqrt(1.0 - cnrm.x * cnrm.x - cnrm.y * cnrm.y));    
}

/*
* Reconstructs the tangent space from a normal and a tangent
* normal: The surface normal
* tangent: The surface tangent
* sigma: Defines the handedness of the tangent space matrix. 1.0 if it is right handend. -1.0 if it is left handed
*/
float3x3 ConstructTangentSpace(float3 normal, float3 tangent, float3 sigma)
{
    float3 n = normalize(normal);
    float3 t = normalize(tangent - n * dot(tangent, n));
    float3 b = cross(n, t) * sigma;
    
    return float3x3(t, b, n);
}

/**
 * Calculates the luminance of an rgb-value.
 * @param rgb The rgb color.
 * @return The luminance of the given rgb color.
 */
float ColorToLuminance(float3 rgb)
{
    return rgb.r * 0.212639 + rgb.g * 0.715169 + rgb.b * 0.072192;
}

/**
 * Extrancts the handedness of the bitangent that is encoded in the z-component of the tangent.
 * @param tangentz The z-component of the tangent with the handedness encoded.
 * @return The handedness of the bitangent (bitangent = handedness * tangent x normal)
 */
float GetBitangentHandedness(float tangentz)
{
	// handedness is in least significant bit of tangent.z
    uint z = asuint(tangentz);
    return (z & 1) > 0 ? 1.0 : -1.0;
}

/**
 * Transforms the given texture coordinates using the provided UV transform.
 * @param texcoords The texture coordinates to transform.
 * @param uvTransform the UV transform. X, Y: UV offset | Z, W: UV scaling.
 * @return The transformed uv coordinates.
 */
float2 TransformTexcoords(float2 texcoords, float4 uvTransform)
{
    return uvTransform.xy + uvTransform.zw * texcoords;
}

#endif // __SHADER_HELPERS_HLSL__