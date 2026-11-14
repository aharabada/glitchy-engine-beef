using System;
using GlitchyEngine.World;
using GlitchyEngine.Content;

namespace GlitchyEngine.Renderer
{
	public struct MeshComponent : IComponent<MeshComponent>
	{
		public AssetHandle<GeometryBinding> Mesh = .Invalid;
	}
}
