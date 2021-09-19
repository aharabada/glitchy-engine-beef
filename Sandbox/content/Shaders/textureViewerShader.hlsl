Texture2D Texture : register(t0);
SamplerState Sampler : register(s0);

cbuffer Constants
{
    float ColorOffset = 0.5f;
    float AlphaOffset = 0.0f;
    float ColorScale = 0.5f;
    float AlphaScale = 1.0f;

    float2 TextureSizeInPixels;
}

struct VS_Input
{
    float2 Position    : POSITION;
    float4x4 Tranform  : TRANSFORM;
    float4 Color       : COLOR;
    float4 UVTransform : TEXCOORD;
};

struct PS_Input
{
    float4 Position : SV_Position;
    float2 TexCoord : TEXCOORD0;
    float4 Color : COLOR;
};

PS_Input VS(VS_Input input)
{
    PS_Input output;

    output.Position = mul(float4(input.Position, 0.0f, 1.0f), input.Tranform);
    output.TexCoord = input.UVTransform.xy + input.UVTransform.zw * input.Position;
    output.Color = input.Color;

    return output;
}

float4 PS(PS_Input input) : SV_Target0
{
    float4 color = Texture.Sample(Sampler, input.TexCoord);

    float4 final = float4(ColorOffset.xxx, AlphaOffset) + color * float4(ColorScale.xxx, AlphaScale);

    return final;
}

#effect[VS=VS, PS=PS]
