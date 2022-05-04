cbuffer SceneConstants
{
    float4x4 ViewProjection = float4x4(1, 0, 0, 0, 
        0, 1, 0, 0, 
        0, 0, 1, 0, 
        0, 0, 0, 1);
}

cbuffer ObjectConstants
{
    float4x4 Transform;
}

cbuffer Constants
{
    float4 BaseColor = float4(1, 0, 1, 1);
    //float3 LightDir = float3(0, 1, 0);
}

struct VS_IN
{
    float3 Position     : POSITION;
    float3 Normal       : NORMAL;
};

struct PS_IN
{
    float4 Position : SV_POSITION;
    float3 WorldPosition : TEXCOORD0;
    float3 Normal   : NORMAL;
};

PS_IN VS(VS_IN input)
{
    PS_IN output;
	
	float4 worldPosition = mul(Transform, float4(input.Position, 1));
	
    output.Position = mul(ViewProjection, worldPosition);
    output.WorldPosition = worldPosition.xyz / worldPosition.w;
    output.Normal = mul((float3x3)Transform, input.Normal);
    
    return output;
}

struct PS_OUT
{
    float4 Color : SV_TARGET0;
    float4 Normal : SV_TARGET1;
    float4 Position : SV_TARGET2;
};

PS_OUT PS(PS_IN input)
{
    input.Normal = normalize(input.Normal);

    float f = distance(input.Normal, input.Normal);

    //float shading = dot(LightDir, input.Normal);
    //float shading = dot(LightDir, LightDir) + 1;
    //shading = clamp(shading, 0.0f, 1.0f);

    //return float4(BaseColor.rgb * shading, 1.0f);

    PS_OUT output = (PS_OUT)0;
    output.Color = BaseColor;
    output.Normal = float4(input.Normal, 1);
    output.Position = float4(input.WorldPosition, 1); 

    return output;
}

#effect[VS=VS,PS=PS]
