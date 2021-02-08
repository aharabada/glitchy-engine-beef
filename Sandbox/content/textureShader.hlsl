Texture2D ColorTexture;

SamplerState TextureSampler;

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
    float2 TexCoord : TEXCOORD;
};

struct PS_IN
{
    float4 Position : SV_POSITION;
    float4 Color    : COLOR;
    float2 TexCoord : TEXCOORD;
};

PS_IN VS(VS_IN input)
{
    PS_IN output;
	
	float4 worldPosition = mul(Transform, float4(input.Position, 1));
	
    output.Position = mul(ViewProjection, worldPosition);
    output.Color = input.Color;
    output.TexCoord = input.TexCoord;
    
    return output;
}

float4 PS(PS_IN input) : SV_TARGET
{
    return input.Color * ColorTexture.Sample(TextureSampler, input.TexCoord);
}