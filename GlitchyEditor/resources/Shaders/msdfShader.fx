#define EDITOR

#include "GlitchyEngine2D.hlsl"
#include "ShaderHelpers.hlsl"

Texture2D<float3> Texture : register(t0);
SamplerState Sampler : register(s0);

cbuffer Material
{
    float2 UnitRange;
}

VS_Output VS(VS_Input input)
{
    VS_Output output;

    output.Position = mul(ViewProjection, mul(input.Transform, float4(input.Position, 0.0f, 1.0f)));
    output.Texcoord = TransformTexcoords(input.Texcoord, input.UVTransform);
    output.Color = input.Color;

#ifdef EDITOR
    output.EntityId = input.EntityId;
#endif

    return output;
}

float median(float r, float g, float b)
{
    return max(min(r, g), min(max(r, g), b));
}

float ScreenPxRange(float2 texcoord)
{
    float2 screenTexSize = 1.0f / fwidth(texcoord);
    return max(0.5f * dot(UnitRange, screenTexSize), 1.0f);
}

struct PS_Output
{
    float4 Color : SV_Target0;
#ifdef EDITOR
    uint EntityId : SV_TARGET1;
#endif
};

PS_Output PS(PS_Input input)
{
    PS_Output output;

    float3 msd = Texture.Sample(Sampler, input.Texcoord);
    float sd = median(msd.r, msd.g, msd.b);
    float screenPxDistance = ScreenPxRange(input.Texcoord) * (sd - 0.5);
    float opacity = clamp(screenPxDistance + 0.5, 0.0, 1.0);

    clip(opacity - 0.001f);

    output.Color = float4(input.Color.rgb, input.Color.a * opacity);

#ifdef EDITOR
    output.EntityId = input.EntityId;
#endif

    return output;
}

#pragma Effect[VS=VS; PS=PS]
