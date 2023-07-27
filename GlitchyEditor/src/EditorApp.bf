using System;
using GlitchyEngine;
using GlitchyEngine.Content;
using GlitchyEditor.Assets;

namespace GlitchyEditor
{
	class EditorApp : Application
	{
		EditorContentManager _contentManager;

		public this(String[] args)
		{
			PushLayer(new EditorLayer(args, _contentManager));

			Log.ClientLogger = new EditorLogger();
			Log.EngineLogger = new EditorLogger() { IsEngineLogger = true };
		}

		protected override IContentManager InitContentManager()
		{
			_contentManager = new EditorContentManager();
			_contentManager.RegisterAssetLoader<EditorTextureAssetLoader>();
			_contentManager.SetAsDefaultAssetLoader<EditorTextureAssetLoader>(".png", ".dds");
			_contentManager.SetAssetPropertiesEditor<EditorTextureAssetLoader>(=> TextureAssetPropertiesEditor.Factory);
			
			_contentManager.RegisterAssetLoader<ModelAssetLoader>();
			_contentManager.SetAsDefaultAssetLoader<ModelAssetLoader>(".glb", ".gltf");
			_contentManager.SetAssetPropertiesEditor<ModelAssetLoader>(=> ModelAssetPropertiesEditor.Factory);
			
			_contentManager.RegisterAssetLoader<MaterialAssetLoader>();
			_contentManager.SetAsDefaultAssetLoader<MaterialAssetLoader>(".mat");
			_contentManager.SetAssetPropertiesEditor<MaterialAssetLoader>(=> MaterialAssetPropertiesEditor.Factory);
			
			_contentManager.RegisterAssetLoader<EffectAssetLoader>();
			_contentManager.SetAsDefaultAssetLoader<EffectAssetLoader>(".hlsl");
			_contentManager.SetAssetPropertiesEditor<EffectAssetLoader>(=> EffectAssetPropertiesEditor.Factory);

			_contentManager.SetContentDirectory("./content");

			return _contentManager;
		}

		[Export, LinkName("CreateApplication")]
		public static Application CreateApplication(String[] args)
		{
			return new EditorApp(args);
		}
	}
}
