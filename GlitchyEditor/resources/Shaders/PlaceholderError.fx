#include "GlitchyEngine.hlsl"

struct VS_IN
{
	float3 Position : POSITION;
};

struct PS_IN
{
	float4 Position : SV_POSITION;
};

PS_IN VS(VS_IN input)
{
	PS_IN output;

	float4 worldPosition = mul(Transform, float4(input.Position, 1));
	output.Position = mul(ViewProjection, worldPosition);

	return output;
}

float4 PS(PS_IN input) : SV_TARGET
{
	return float4(1, 0, 1, 1);
}

#pragma Effect[VS = VS; PS = PS]
