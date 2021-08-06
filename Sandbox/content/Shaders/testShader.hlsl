cbuffer SceneConstants
{
    float4x4 ViewProjection = float4x4(1, 0, 0, 0, 
        0, 1, 0, 0, 
        0, 0, 1, 0, 
        0, 0, 0, 1);
}

cbuffer ObjectConstants
{
    float4x4 Transform;
}

cbuffer Constants
{
    float4 BaseColor;
    float3 LightDir;
}

struct VS_IN
{
    float3 Position : POSITION;
    float3 Normal   : NORMAL;
};

struct PS_IN
{
    float4 Position : SV_POSITION;
    float3 Normal   : NORMAL;
};

PS_IN VS(VS_IN input)
{
    PS_IN output;
	
	float4 worldPosition = mul(Transform, float4(input.Position, 1));
	
    output.Position = mul(ViewProjection, worldPosition);
    output.Normal = mul((float3x3)Transform, input.Normal);
    
    return output;
}

float4 PS(PS_IN input) : SV_TARGET
{
    input.Normal = normalize(input.Normal);

    float shading = dot(LightDir, input.Normal);
    shading = clamp(shading, 0.0f, 1.0f);

    return BaseColor * shading;
}

#effect[VS=VS,PS=PS]
