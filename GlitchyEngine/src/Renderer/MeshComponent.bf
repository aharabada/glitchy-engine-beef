using System;
using GlitchyEngine.World;
using GlitchyEngine.Content;

namespace GlitchyEngine.Renderer
{
	public struct MeshComponent// : IDisposableComponent
	{
		public AssetHandle<GeometryBinding> Mesh {get; set mut;} = .Invalid;
		/*
		private GeometryBinding _mesh;
		public AssetHandle<GeometryBinding> Mesh
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
		}*/
	}
}
