using GlitchyEngine.Renderer;
using System;
using GlitchyEngine.Content;

namespace GlitchyEngine.World
{
	/// A component that allows to render a mesh.
	public struct MeshRendererComponent
	{
		public AssetHandle<Material> Material = .Invalid;
	}
}
