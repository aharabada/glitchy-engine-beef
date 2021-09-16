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
    float4 BaseColor;
    float3 LightDir;
}

cbuffer SkinningMatrices
{
    matrix SkinningMatrices[255];
    float3x3 InvTransSkinningMatrices[255];
}

struct VS_IN
{
    float3 Position     : POSITION;
    float3 Normal       : NORMAL;
    uint4  JointIndices : JOINTS_0;
    float4 JointWeights : WEIGHTS_0;
};

struct PS_IN
{
    float4 Position : SV_POSITION;
    float3 Normal   : NORMAL;
};

PS_IN VS(VS_IN input)
{
    PS_IN output;
	
    // Unanimated position in modelspace
    float4 positionRaw = float4(input.Position, 1);

    // Calculate animated position in modelspace
    
    float4 position = 
        mul(SkinningMatrices[input.JointIndices.x], positionRaw) * input.JointWeights.x + 
        mul(SkinningMatrices[input.JointIndices.y], positionRaw) * input.JointWeights.y + 
        mul(SkinningMatrices[input.JointIndices.z], positionRaw) * input.JointWeights.z + 
        mul(SkinningMatrices[input.JointIndices.w], positionRaw) * input.JointWeights.w;
    
    float3 normal = 
        mul(InvTransSkinningMatrices[input.JointIndices.x], input.Normal) * input.JointWeights.x + 
        mul(InvTransSkinningMatrices[input.JointIndices.y], input.Normal) * input.JointWeights.y + 
        mul(InvTransSkinningMatrices[input.JointIndices.z], input.Normal) * input.JointWeights.z + 
        mul(InvTransSkinningMatrices[input.JointIndices.w], input.Normal) * input.JointWeights.w;
    
    //position = saturate(position - 1000) + positionRaw;
    
    //float4 position = mul(SkinningMatrices[input.JointIndices.x], positionRaw);

	float4 worldPosition = mul(Transform, position);
	
    output.Position = mul(ViewProjection, worldPosition);
    output.Normal = mul((float3x3)Transform, normal);
    
    return output;
}

float4 PS(PS_IN input) : SV_TARGET
{
    input.Normal = normalize(input.Normal);

    float shading = dot(LightDir, input.Normal);
    //float shading = dot(LightDir, LightDir) + 1;
    shading = clamp(shading, 0.0f, 1.0f);

    return BaseColor * shading;
}

#effect[VS=VS,PS=PS]
