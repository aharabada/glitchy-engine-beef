#include "ShaderHelpers.hlsl"

Texture2DArray Texture : register(t0);
SamplerState Sampler : register(s0);

Texture2DArray<int4> IntTexture : register(t1);
SamplerState IntSampler : register(s1);

Texture2DArray<uint4> UIntTexture : register(t2);
SamplerState UIntSampler : register(s2);

#define SWIZZLE_ZERO 0
#define SWIZZLE_ONE 1
#define SWIZZLE_R 2
#define SWIZZLE_G 3
#define SWIZZLE_B 4
#define SWIZZLE_A 5
#define SWIZZLE_ONE_MINUS_R 6
#define SWIZZLE_ONE_MINUS_G 7
#define SWIZZLE_ONE_MINUS_B 8
#define SWIZZLE_ONE_MINUS_A 9

cbuffer Constants
{
    float ColorOffset = 0.5;
    float AlphaOffset = 0.0;
    float ColorScale = 0.5;
    float AlphaScale = 1.0;

    float MipLevel = 0.0;
    float ArraySlice = 0.0;

    // 0: Float | 1: Int | 2: Uint
    int Mode = 0;

    int4 Swizzle = int4(SWIZZLE_R, SWIZZLE_G, SWIZZLE_B, SWIZZLE_A);

    float2 Texels;

    float4x4 WorldViewProjection;

    bool ShowTexelBorders = true;
    float TexelBorderCutoff = 10;
}

struct VS_Input
{
    float2 Position     : POSITION;
    float2 Texcoord     : TEXCOORD0;
};

struct PS_Input
{
    float4 Position : SV_Position;
    float2 Texcoord : TEXCOORD0;
};

PS_Input VS(VS_Input input)
{
    PS_Input output;

    output.Position = mul(WorldViewProjection, float4(input.Position, 0.0f, 1.0f));
    output.Texcoord = input.Texcoord;

    return output;
}

void SwizzleColor(int swizzleMode, float4 colorToSwizzle, inout float output)
{
    switch (swizzleMode)
    {
	    case SWIZZLE_ZERO:
            output = 0.0;
            break;
	    case SWIZZLE_ONE:
            output = 1.0;
            break;
	    case SWIZZLE_R:
            output = colorToSwizzle.r;
            break;
	    case SWIZZLE_G:
            output = colorToSwizzle.g;
            break;
	    case SWIZZLE_B:
            output = colorToSwizzle.b;
            break;
	    case SWIZZLE_A:
            output = colorToSwizzle.a;
            break;
	    case SWIZZLE_ONE_MINUS_R:
            output = 1.0 - colorToSwizzle.r;
            break;
	    case SWIZZLE_ONE_MINUS_G:
            output = 1.0 - colorToSwizzle.g;
            break;
	    case SWIZZLE_ONE_MINUS_B:
            output = 1.0 - colorToSwizzle.b;
            break;
	    case SWIZZLE_ONE_MINUS_A:
            output = 1.0 - colorToSwizzle.a;
            break;
		default:
            break;
    }
}

/**
 * Returns whether or not the current pixel lies on the border between two texels.
 */
void ApplyTexelBorder(float2 texelPosition, inout float4 color)
{
    // Calculate derivatives of texelPosition -> how many texels to we move if we move one pixel in x/y direction
    float2 dudx = ddx(texelPosition);
    float2 dudy = ddy(texelPosition);

    // This is the reciprocal of the screen size of one texel.
    float grad = float2(length(dudx), length(dudy));
    
    float2 pixelsPerTexel = 1.0f / grad;

    // Threshold is half the size of a screen pixel in texel-space.
    float2 threshold = grad / 2.0f;

    // Calculate the distance between the screen pixel and the texel border in texels.
    float2 fracPart = frac(texelPosition);
    float2 distanceToBorder = min(fracPart, 1.0 - fracPart);
    
    if (any(distanceToBorder < threshold))
    {
        // Ensure the border is always at least 0.5 luminance away from the texel.
        // TODO: This can flicker while moving/zooming, because we are by design on a texel border!
        float luminance = ColorToLuminance(color.rgb);
        float4 borderColor = (luminance > 0.5f) ? float4(0, 0, 0, 1) : float4(1, 1, 1, 1);

        color = lerp(color, borderColor, clamp((min(pixelsPerTexel.x, pixelsPerTexel.y) - TexelBorderCutoff / 2.0) / TexelBorderCutoff, 0.0f, 0.8f));
    }
}

float4 PS(PS_Input input) : SV_Target0
{
    float4 outputColor;

    float2 texelPosition = input.Texcoord * Texels;

    if (Mode == 0)
    {
        //float4 color = Texture.SampleLevel(Sampler, float3(input.Texcoord, ArraySlice), MipLevel);
        // Quasi next neighbor
        float4 color = Texture.Load(int4(texelPosition, ArraySlice, MipLevel));
        outputColor = float4(ColorOffset.xxx, AlphaOffset) + color * float4(ColorScale.xxx, AlphaScale);
    }
    else if (Mode == 1)
    {
        int4 color = IntTexture.Load(int4(texelPosition, ArraySlice, MipLevel));
        outputColor = float4(ColorOffset.xxx, AlphaOffset) + color * float4(ColorScale.xxx, AlphaScale);
    }
    else if (Mode == 2)
    {
        uint4 color = UIntTexture.Load(int4(texelPosition, ArraySlice, MipLevel));
        outputColor = float4(ColorOffset.xxx, AlphaOffset) + color * float4(ColorScale.xxx, AlphaScale);
    }

    float4 swizzledOutput = float4(0, 0, 0, 1);

    SwizzleColor(Swizzle.r, outputColor, swizzledOutput.r);
    SwizzleColor(Swizzle.g, outputColor, swizzledOutput.g);
    SwizzleColor(Swizzle.b, outputColor, swizzledOutput.b);
    SwizzleColor(Swizzle.a, outputColor, swizzledOutput.a);

    if (ShowTexelBorders)
    {
        ApplyTexelBorder(texelPosition, swizzledOutput);
    }

    return swizzledOutput;
}

#pragma Effect[VS=VS; PS=PS]
