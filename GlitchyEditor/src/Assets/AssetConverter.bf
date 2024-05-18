using System.Collections;
using GlitchyEditor.Assets.Importers;
using GlitchyEngine;

namespace GlitchyEditor.Assets;

class AssetConverter
{
	private append Queue<AssetFile> _queue = .() ~ delete:append _;

	private EditorContentManager _contentManager;

	public this(EditorContentManager contentManager)
	{
		_contentManager = contentManager;
	}

	public void QueueForProcessing(AssetFile assetFile)
	{
		_queue.Add(assetFile);
	}

	public void Update()
	{
		if (_queue.Count == 0)
			return;

		for (AssetFile assetFile in _queue)
		{
			Process(assetFile);
		}

		_queue.Clear();
	}

	private void Process(AssetFile assetFile)
	{
		IAssetImporter importer = _contentManager.GetAssetImporter(assetFile);

		if (importer == null)
		{
			Log.EngineLogger.Error("Importer is null!");
		}

		ImportedResource importedResource = importer.Import(assetFile.AssetFile.Path,
			assetFile.AssetFile.Identifier, assetFile.AssetConfig.ImporterConfig);

		delete importedResource;
	}
}