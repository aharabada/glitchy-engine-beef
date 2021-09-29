Texture2D<float3> Texture : register(t0);
SamplerState Sampler : register(s0);

cbuffer Constants
{
    float4x4 ViewProjection;
    float2 UnitRange;
    float screenPixelRange = 2;
}

struct VS_Input
{
    float2 Position    : POSITION;
    float2 Texcoord    : TEXCOORD0;
    float4x4 Tranform  : TRANSFORM;
    float4 Color       : COLOR;
    float4 UVTransform : TEXCOORD1;
};

struct PS_Input
{
    float4 Position : SV_Position;
    float2 TexCoord : TEXCOORD0;
    float4 Color    : COLOR;
};

PS_Input VS(VS_Input input)
{
    PS_Input output;

    output.Position = mul(ViewProjection, mul(input.Tranform, float4(input.Position, 0.0f, 1.0f)));
    output.TexCoord = input.UVTransform.xy + input.UVTransform.zw * input.Texcoord;
    output.Color = input.Color;

    return output;
}

float median(float r, float g, float b) {
    return max(min(r, g), min(max(r, g), b));
}

float ScreenPxRange(float2 texcoord) {
    float2 screenTexSize = 1.0f / fwidth(texcoord);
    return max(0.5f * dot(UnitRange, screenTexSize), 1.0f);
}

float4 PS(PS_Input input) : SV_Target0
{
    float3 msd = Texture.Sample(Sampler, input.TexCoord);
    float sd = median(msd.r, msd.g, msd.b);
    float screenPxDistance = ScreenPxRange(input.TexCoord) * (sd - 0.5);
    float opacity = clamp(screenPxDistance + 0.5, 0.0, 1.0);

    return float4(input.Color.rgb, opacity * input.Color.a);
}

#effect[VS=VS, PS=PS]