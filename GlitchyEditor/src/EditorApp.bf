using System;
using GlitchyEngine;
using GlitchyEngine.Content;
using GlitchyEditor.Assets;
using GlitchyEditor.Assets.Importers;
using GlitchyEditor.Assets.Processors;
using GlitchyEditor.Assets.Exporters;

namespace GlitchyEditor
{
	class EditorApp : Application
	{
		EditorContentManager _contentManager;

		public this(String[] args)
		{
			Log.ClientLogger = new EditorLogger();
			Log.EngineLogger = new EditorLogger() { IsEngineLogger = true };

			PushLayer(new EditorLayer(args, _contentManager));
		}

		protected override IContentManager InitContentManager()
		{
			_contentManager = new EditorContentManager();

			// TODO: Get rid of legacy loaders
			_contentManager.RegisterAssetLoader<ModelAssetLoader>();
			_contentManager.SetAsDefaultAssetLoader<ModelAssetLoader>(".glb", ".gltf");
			_contentManager.SetAssetPropertiesEditor<ModelAssetLoader>(=> ModelAssetPropertiesEditor.Factory);
			
			_contentManager.RegisterAssetLoader<MaterialAssetLoader>();
			_contentManager.SetAsDefaultAssetLoader<MaterialAssetLoader>(".mat");
			_contentManager.SetAssetPropertiesEditor<MaterialAssetLoader>(=> MaterialAssetPropertiesEditor.Factory);
			
			_contentManager.RegisterAssetLoader<EffectAssetLoader>();
			_contentManager.SetAsDefaultAssetLoader<EffectAssetLoader>(".hlsl");
			_contentManager.SetAssetPropertiesEditor<EffectAssetLoader>(=> EffectAssetPropertiesEditor.Factory);

			_contentManager.RegisterAssetImporter<TextureImporter>();
			_contentManager.RegisterAssetProcessor<TextureProcessor>();
			_contentManager.RegisterAssetExporter<TextureExporter>();

			_contentManager.RegisterAssetExporter<SpriteExporter>();
			
			_contentManager.RegisterAssetImporter<ShaderImporter>();
			_contentManager.RegisterAssetProcessor<ShaderProcessor>();
			_contentManager.RegisterAssetExporter<ShaderExporter>();

			_contentManager.SetGlobalAssetCacheDirectory(".cache");
			_contentManager.SetResourcesDirectory("Resources");

			return _contentManager;
		}

		[Export, LinkName("CreateApplication")]
		public static Application CreateApplication(String[] args)
		{
			return new EditorApp(args);
		}
	}
}
