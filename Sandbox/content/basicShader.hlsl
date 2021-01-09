cbuffer SceneConstants : register(b0)
{
    float4x4 Transform = float4x4(1, 0, 0, 0, 
        0, 1, 0, 0, 
        0, 0, 1, 0, 
        0, 0, 0, 1);
}

cbuffer Constants : register(b1)
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
    output.Position = mul(Transform, float4(input.Position, 1));
    output.Color = input.Color;
    
    return output;
}

float4 PS(PS_IN input) : SV_TARGET
{
    return input.Color * BaseColor;
}