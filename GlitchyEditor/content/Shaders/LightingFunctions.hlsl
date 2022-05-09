#define PI 3.14159265358979323846f

/**
 * Calculates the diffuse lighting of a lambertian surface
 * @param diffuseColor (rho/ pi) * C_diffuse
 * @param illuminanceColor The product of the "brightness" and the light color.
 * @param n_dot_l The dot product of the surface normal and the light direction.
 */
float3 CalculateDiffuseReflection(float3 diffuseColor, float3 illuminanceColor, float3 n_dot_l)
{
    float3 directColor = illuminanceColor * saturate(n_dot_l);

    return (directColor * diffuseColor);
}

/**
 * Calculates the blinn-phong-specular reflection
 * @param n The normalized surface normal
 * @param h The normalized half way vector (nrm(l + v))
 * @param alpha The reflections alpha-value
 * @param illuminanceColor The product of the "brightness" and the light color.
 * @param n_dot_l The dot product of the surface normal and the light direction.
 */
float3 CalculateSpecularReflection(float3 n, float3 h, float alpha, float3 illuminanceColor, float n_dot_l)
{
    float highlight = pow(saturate(dot(n, h)), alpha) * float(n_dot_l > 0.0);
    return (illuminanceColor * highlight); // Todo:  * SpecularColor
}