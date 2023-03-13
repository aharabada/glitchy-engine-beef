using GlitchyEngine.Renderer;
using System;
using GlitchyEngine.Content;

namespace GlitchyEngine.World
{
	/// A component that allows to render a mesh.
	public struct MeshRendererComponent// : IDisposableComponent
	{
		private AssetHandle<Material> _material;

		public AssetHandle<Material> Material
		{
			[Inline]
			get => _material;
			set mut
			{
				if(_material == value)
					return;

				_material = value;
			}
		}

		/*public void Dispose() mut
		{
			_material?.ReleaseRef();
		}*/
	}
}
