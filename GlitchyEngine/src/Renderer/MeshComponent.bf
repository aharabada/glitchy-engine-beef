using System;
using GlitchyEngine.World;

namespace GlitchyEngine.Renderer
{
	public struct MeshComponent : IDisposableComponent
	{
		private GeometryBinding _mesh;
		public GeometryBinding Mesh
		{
			[Inline]
			get => _mesh;
			set mut
			{
				if(_mesh == value)
					return;

				SetReference!(_mesh, value);
			}
		}

		public void Dispose() mut
		{
			ReleaseRefAndNullify!(_mesh);
		}
	}
}
