using GlitchyEngine.Content;
using System;
using System.IO;

namespace GlitchyEditor.Assets;

interface IAssetSaver
{
	Result<void> EditorSaveAsset(Stream file, Asset asset, AssetLoaderConfig config, StringView assetIdentifier, StringView? subAsset, IContentManager contentManager);
}