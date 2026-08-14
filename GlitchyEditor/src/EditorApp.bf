using System;
using GlitchyEngine;
using GlitchyEngine.Content;
using GlitchyEditor.Assets;
using GlitchyEditor.Assets.Importers;
using GlitchyEditor.Assets.Processors;
using GlitchyEditor.Assets.Exporters;
using DirectX.Common;
using GlitchyEditor.Platform.Windows;
using GlitchyEditor.Multithreading;
using System.Threading;
using GlitchyEditor.Platform;
using System.Diagnostics;
using GlitchyEditor.ImGui;
using GlitchyEngine.Events;
using GlitchyEditor.Settings;

namespace GlitchyEditor
{
	class EditorApp : Application
	{
		EditorContentManager _contentManager;

		public new static EditorApp Instance => Application.Instance as EditorApp;

		private append BackgroundTaskManager _backgroundTaskManager = .();

		public BackgroundTaskManager BackgroundTaskManager => _backgroundTaskManager;

#if IMGUI
		private ImGuiLayer _imGuiLayer;
#endif

		private EditorLayer _editorLayer;

		public Settings Settings { get; private set; } = new .() ~ delete _;
		
		public this(String[] args)
		{
			/*while(!Debug.IsDebuggerPresent)
			{
				Thread.Sleep(10);
			}*/

			Log.ClientLogger = new EditorLogger();
			Log.EngineLogger = new EditorLogger() { IsEngineLogger = true };

			_backgroundTaskManager.Init();

			DragDropManager.Init();
			
			GlitchyEditor.Settings.Settings.Load();

#if IMGUI
			_imGuiLayer = new ImGuiLayer();
			PushOverlay(_imGuiLayer);
#endif

			_editorLayer = new EditorLayer(args, _contentManager);
			PushLayer(_editorLayer);

			Settings.OnApplySettings.Add(new (s, e) => {
			   OnEvent(scope SettingsAppliedEvent());
			});
			Settings.Apply();
		}

		public ~this()
		{
			// TODO: We should clear the queue of _backgroundTaskManager
			// TODO: We should maybe also notify the user that that would happen!

			PopLayer(_editorLayer);

			DragDropManager.Deinit();

			_backgroundTaskManager.Deinit();
		}

		protected override IContentManager InitContentManager()
		{
			_contentManager = new EditorContentManager();

			// TODO: Get rid of legacy loaders
			_contentManager.RegisterAssetLoader<ModelAssetLoader>();
			_contentManager.SetAsDefaultAssetLoader<ModelAssetLoader>(".glb", ".gltf");
			_contentManager.SetAssetPropertiesEditor<ModelAssetLoader>(=> ModelAssetPropertiesEditor.Factory);
			
			_contentManager.RegisterAssetImporter<TextureImporter>();
			_contentManager.RegisterAssetProcessor<TextureProcessor>();
			_contentManager.RegisterAssetExporter<TextureExporter>();

			_contentManager.RegisterAssetExporter<SpriteExporter>();
			
			_contentManager.RegisterAssetImporter<ShaderImporter>();
			_contentManager.RegisterAssetProcessor<ShaderProcessor>();
			_contentManager.RegisterAssetExporter<ShaderExporter>();

			_contentManager.RegisterAssetImporter<MaterialImporter>();
			_contentManager.RegisterAssetProcessor<MaterialProcessor>();
			_contentManager.RegisterAssetExporter<MaterialExporter>();

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
