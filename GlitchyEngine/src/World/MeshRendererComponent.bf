using GlitchyEngine.Renderer;
using System;

namespace GlitchyEngine.World
{
	/// A component that allows to render a mesh.
	public struct MeshRendererComponent : IDisposableComponent
	{
		private Material _material;

		public Material Material
		{
			[Inline]
			get => _material;
			set mut
			{
				if(_material == value)
					return;

				_material?.ReleaseRef();
				_material = value;
				_material?.AddRef();
			}
		}

		public static void DisposeComponent(void* component)
		{
			Self* meshRenderComponent = (Self*)component;
			meshRenderComponent._material?.ReleaseRef();
		}
	}
}
