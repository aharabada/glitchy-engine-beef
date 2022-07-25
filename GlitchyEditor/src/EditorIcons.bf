using System;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using GlitchyEngine;

namespace GlitchyEditor
{
	class EditorIcons : RefCounted
	{
		Texture2D _texture ~ _.ReleaseRef();

		public SubTexture2D DirectionalLight ~ _.ReleaseRef();
		public SubTexture2D Camera ~ _.ReleaseRef();
		public SubTexture2D Folder ~ _.ReleaseRef();
		public SubTexture2D File ~ _.ReleaseRef();

		public SamplerState SamplerState
		{
			get => _texture.SamplerState;
			set => _texture.SamplerState = value;
		}

		public this(String texturePath, Vector2 iconSize)
		{
			_texture = new Texture2D(texturePath);
			
			Vector2 pen = .();

			DirectionalLight = GetNextGridTexture(ref pen, iconSize);
			Camera = GetNextGridTexture(ref pen, iconSize);
			Folder = GetNextGridTexture(ref pen, iconSize);
			File = GetNextGridTexture(ref pen, iconSize);
		}

		private SubTexture2D GetNextGridTexture(ref Vector2 pen, Vector2 iconSize)
		{
			SubTexture2D subTexture = .CreateFromGrid(_texture, pen, iconSize);

			pen.X += 1.0f;

			if (pen.X >= (_texture.Width / iconSize.X))
			{
				pen.X = 0;
				pen.Y += 1.0f;
			}

			Log.EngineLogger.AssertDebug(pen.Y <=(_texture.Height / iconSize.Y));

			return subTexture;
		}
	}
}