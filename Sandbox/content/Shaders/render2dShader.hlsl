cbuffer Constants : register(b0)
{
    float3x3 World;
    float4 Color;
    bool HasTexture;
};

Texture2D Texture : register(t0);
SamplerState Sampler : register(s0);

struct VS_Input
{
    float2 Position : POSITION;
};

struct PS_Input
{
    float4 Position : SV_Position;
    float2 TexCoord : TEXCOORD;
};

PS_Input VS(VS_Input input)
{
    PS_Input output;

    output.TexCoord = input.Position;
    output.Position = float4(mul(float3(input.Position, 1.0f), World), 1.0f);

    return output;
}

float4 PS(PS_Input input) : SV_Target0
{
    float4 color = Color;

    if(HasTexture)
    {
        color *= Texture.Sample(Sampler, input.TexCoord);
    }

    return color;
}

#effect[VS=VS, PS=PS]