using System;
using GlitchyEngine.Renderer;
using GlitchyEngine.Renderer.Animation;

namespace GlitchyEngine.World
{
	/// A component that allows to render a skinned mesh.
	public struct SkinnedMeshRendererComponent : IDisposableComponent
	{
		private Material _material;
		private Skeleton _skeleton;

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

		public Skeleton Skeleton
		{
			[Inline]
			get => _skeleton;
			set mut
			{
				if(_skeleton == value)
					return;

				_skeleton?.ReleaseRef();
				_skeleton = value;
				_skeleton?.AddRef();
			}
		}

		public static void DisposeComponent(void* component)
		{
			Self* meshRenderComponent = (Self*)component;

			meshRenderComponent._material?.ReleaseRef();
			meshRenderComponent._skeleton?.ReleaseRef();
		}
	}
}
