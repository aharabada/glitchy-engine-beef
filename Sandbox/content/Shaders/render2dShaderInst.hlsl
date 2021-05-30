Texture2D Texture : register(t0);
SamplerState Sampler : register(s0);

struct VS_Input
{
    float2 Position   : POSITION;
    float4x4 Tranform : TRANSFORM;
    float4 Color      : COLOR;
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
    output.TexCoord = input.Position;
    output.Color = input.Color;

    return output;
}

float4 PS(PS_Input input) : SV_Target0
{
    float4 color = input.Color * Texture.Sample(Sampler, input.TexCoord);
    
    return color;
}

#effect[VS=VS, PS=PS]