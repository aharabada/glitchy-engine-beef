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
}

struct VS_IN
{
    float3 Position : POSITION;
    float4 Color    : COLOR;
};

struct PS_IN
{
    float4 Position : SV_POSITION;
    float4 Color    : COLOR;
};

PS_IN VS(VS_IN input)
{
    PS_IN output;
	
	float4 worldPosition = mul(Transform, float4(input.Position, 1));
	
    output.Position = mul(ViewProjection, worldPosition);
    output.Color = input.Color;
    
    return output;
}

float4 PS(PS_IN input) : SV_TARGET
{
    return input.Color * BaseColor;
}