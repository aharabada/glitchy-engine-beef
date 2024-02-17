using System;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using GlitchyEngine;
using GlitchyEngine.Content;

namespace GlitchyEditor
{
	class EditorIcons : RefCounted
	{
		AssetHandle<Texture2D> _texture;

		public SubTexture2D DirectionalLight ~ _.ReleaseRef();
		public SubTexture2D Camera ~ _.ReleaseRef();
		public SubTexture2D Folder ~ _.ReleaseRef();
		public SubTexture2D File ~ _.ReleaseRef();
		public SubTexture2D Play ~ _.ReleaseRef();
		public SubTexture2D Stop ~ _.ReleaseRef();
		public SubTexture2D Simulate ~ _.ReleaseRef();
		public SubTexture2D Pause ~ _.ReleaseRef();
		public SubTexture2D SingleStep ~ _.ReleaseRef();
		public SubTexture2D Error ~ _.ReleaseRef();
		public SubTexture2D Warning ~ _.ReleaseRef();
		public SubTexture2D Info ~ _.ReleaseRef();
		public SubTexture2D Trace ~ _.ReleaseRef();
		public SubTexture2D File_Scene ~ _.ReleaseRef();
		public SubTexture2D File_Material ~ _.ReleaseRef();
		public SubTexture2D File_CSharpScript ~ _.ReleaseRef();
		public SubTexture2D File_Shader ~ _.ReleaseRef();

		public SamplerState SamplerState
		{
			get => _texture.Get().SamplerState;
			set => _texture.Get().SamplerState = value;
		}

		public this(String texturePath, float2 iconSize)
		{
			_texture = Content.LoadAsset(texturePath, null, true);
			
			float2 pen = .();

			DirectionalLight = GetNextGridTexture(ref pen, iconSize);
			Camera = GetNextGridTexture(ref pen, iconSize);
			Folder = GetNextGridTexture(ref pen, iconSize);
			File = GetNextGridTexture(ref pen, iconSize);
			Play = GetNextGridTexture(ref pen, iconSize);
			Stop = GetNextGridTexture(ref pen, iconSize);
			Simulate = GetNextGridTexture(ref pen, iconSize);
			Pause = GetNextGridTexture(ref pen, iconSize);
			SingleStep = GetNextGridTexture(ref pen, iconSize);
			Error = GetNextGridTexture(ref pen, iconSize);
			Warning = GetNextGridTexture(ref pen, iconSize);
			Info = GetNextGridTexture(ref pen, iconSize);
			Trace = GetNextGridTexture(ref pen, iconSize);
			File_Scene = GetNextGridTexture(ref pen, iconSize);
			File_Material = GetNextGridTexture(ref pen, iconSize);
			File_CSharpScript = GetNextGridTexture(ref pen, iconSize);
			File_Shader = GetNextGridTexture(ref pen, iconSize);
		}

		private SubTexture2D GetNextGridTexture(ref float2 pen, float2 iconSize)
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