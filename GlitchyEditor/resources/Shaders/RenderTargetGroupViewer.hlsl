Texture2DArray Texture : register(t0);
SamplerState Sampler : register(s0);

Texture2DArray<int4> IntTexture : register(t1);
SamplerState IntSampler : register(s1);

Texture2DArray<uint4> UIntTexture : register(t2);
SamplerState UIntSampler : register(s2);

#define SWIZZLE_NONE 0
#define SWIZZLE_R 1
#define SWIZZLE_G 2
#define SWIZZLE_B 3
#define SWIZZLE_A 4

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
		default:
            break;
    }
}

float4 PS(PS_Input input) : SV_Target0
{
    float4 outputColor;

    if (Mode == 0)
    {
        //float4 color = Texture.SampleLevel(Sampler, float3(input.Texcoord, ArraySlice), MipLevel);
        // Quasi next neighbor
        float4 color = Texture.Load(int4(input.Texcoord * Texels, ArraySlice, MipLevel));
        outputColor = float4(ColorOffset.xxx, AlphaOffset) + color * float4(ColorScale.xxx, AlphaScale);
    }
    else if (Mode == 1)
    {
        int4 color = IntTexture.Load(int4(input.Texcoord * Texels, ArraySlice, MipLevel));
        outputColor = float4(ColorOffset.xxx, AlphaOffset) + color * float4(ColorScale.xxx, AlphaScale);
    }
    else if (Mode == 2)
    {
        uint4 color = UIntTexture.Load(int4(input.Texcoord * Texels, ArraySlice, MipLevel));
        outputColor = float4(ColorOffset.xxx, AlphaOffset) + color * float4(ColorScale.xxx, AlphaScale);
    }

    float4 swizzledOutput = float4(0, 0, 0, 1);

    SwizzleColor(Swizzle.r, outputColor, swizzledOutput.r);
    SwizzleColor(Swizzle.g, outputColor, swizzledOutput.g);
    SwizzleColor(Swizzle.b, outputColor, swizzledOutput.b);
    SwizzleColor(Swizzle.a, outputColor, swizzledOutput.a);

    return swizzledOutput;
}

#pragma Effect[VS=VS; PS=PS]
