Texture2D<float3> Texture : register(t0);
SamplerState Sampler : register(s0);

cbuffer Constants
{
    float screenPixelRange = 2;
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

float median(float r, float g, float b) {
    return max(min(r, g), min(max(r, g), b));
}

float4 PS(PS_Input input) : SV_Target0
{
    float3 msd = Texture.Sample(Sampler, input.TexCoord);
    float sd = median(msd.r, msd.g, msd.b);
    float screenPxDistance = screenPixelRange * (sd - 0.5);
    float opacity = clamp(screenPxDistance + 0.5, 0.0, 1.0);
    //color = mix(bgColor, fgColor, opacity);

    //float4 color = lerp(float4(0, 0, 0, 0), input.Color, opacity);

    //return color;

    return float4(input.Color.rgb, opacity * input.Color.a);
}

#effect[VS=VS, PS=PS]