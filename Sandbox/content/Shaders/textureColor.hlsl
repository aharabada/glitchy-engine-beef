Texture2D Texture : register(t0);
SamplerState Sampler : register(s0);

cbuffer Constants : register(b0)
{
    float4x4 World;
    
    // TODO: move ViewProjection to seperate cbuffer
    float4x4 ViewProjection;

    float4 Color;
    float4 UVTransform;
};

struct VS_Input
{
    float2 Position : POSITION;
    float2 Texcoord : TEXCOORD;
};

struct PS_Input
{
    float4 Position : SV_Position;
    float2 Texcoord : TEXCOORD;
};

PS_Input VS(VS_Input input)
{
    PS_Input output;

    output.Position = mul(ViewProjection, mul(World, float4(input.Position, 0.0f, 1.0f)));
    output.Texcoord = UVTransform.xy + UVTransform.zw * input.Texcoord;

    return output;
}

float4 PS(PS_Input input) : SV_Target0
{
    return Texture.Sample(Sampler, input.Texcoord) * Color;
}

#effect[VS=VS, PS=PS]