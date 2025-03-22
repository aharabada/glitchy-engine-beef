using Bon;
using GlitchyEngine.Content;
using ImGui;

namespace GlitchyEditor.Assets.Importers;

[BonTarget, BonPolyRegister]
abstract class Config
{
	[BonIgnore]
	protected bool _changed = false;

	public bool Changed => _changed;

	protected bool SetIfChanged<T>(ref T field, T value)
	{
		if (field == value)
			return false;

		field = value;
		_changed = true;

		return true;
	}
	
	public abstract void ShowEditor(AssetFile assetFile);
}

[BonTarget, BonPolyRegister]
class AssetImporterConfig : Config
{
	public override void ShowEditor(AssetFile assetFile)
	{

	}
}

[BonTarget, BonPolyRegister]
class AssetProcessorConfig : Config
{
	public override void ShowEditor(AssetFile assetFile)
	{

	}
}

[BonTarget, BonPolyRegister]
class AssetExporterConfig : Config
{
	[BonInclude]
	private AssetCompression _compression;

	public AssetCompression Compression
	{
		get => _compression;
		set => SetIfChanged(ref _compression, value);
	}
	
	public override void ShowEditor(AssetFile assetFile)
	{
		ImGui.PropertyTableStartNewProperty("Compression");
		ImGui.AttachTooltip("Specifies the compression method used to compress the processed asset.");

		AssetCompression compression = _compression;
		if (ImGui.EnumCombo<AssetCompression>("##Compression", ref compression))
		{
			Compression = compression;
		}
	}
}
