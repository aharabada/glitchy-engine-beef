using Bon;
using GlitchyEngine.Content;

namespace GlitchyEditor.Assets.Importers;

[BonTarget, BonPolyRegister]
abstract class Config
{
	[BonIgnore]
	protected bool _changed;

	public bool Changed => _changed;

	protected bool SetIfChanged<T>(ref T field, T value)
	{
		if (field == value)
			return false;

		field = value;
		_changed = true;

		return true;
	}
}

[BonTarget, BonPolyRegister]
class AssetImporterConfig : Config
{

}

[BonTarget, BonPolyRegister]
class AssetProcessorConfig : Config
{

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
}
