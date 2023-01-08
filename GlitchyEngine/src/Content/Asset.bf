using GlitchyEngine.Core;
using System;
using Bon;
using Bon.Integrated;
using System.Reflection;
using System.IO;

namespace GlitchyEngine.Content;

[BonTarget]
class Asset : RefCounter
{
	private append String _identifier;

	internal IContentManager _contentManager;

	/// Gets the identifier of this asset.
	/// @remarks The identifier is the name with which the asset was registered in the content manager.
	/// 	This identifier can be used to request the Asset from the content manager.
	public StringView Identifier
	{
		get => _identifier;
		set
		{
			_contentManager?.UpdateAssetIdentifier(this, _identifier, value);

			_identifier.Set(value);
			// TODO: do we need to tell the content manager, that the name changed?
		}
	}

	// TODO: do we need unmanaged assets? Probably not...
	/// Gets the content manager that manages this asset; or null if this asset isn't managed.
	public IContentManager ContentManager => _contentManager;

	static this
	{
		gBonEnv.typeHandlers.Add(typeof(Asset),
			    ((.)new => AssetSerialize, new => AssetDeserialize));
	}

	protected ~this()
	{
		// TODO: crash when _contentManager is deleted first...
		// TODO: unregister from content manager
		_contentManager?.UnmanageAsset(this);
	}

	static void AssetSerialize(BonWriter writer, ValueView value, BonEnvironment environment)
	{
		Log.EngineLogger.Assert(value.type == typeof(Asset));

	    let identifier = value.Get<Asset>().Identifier;
	    writer.String(identifier);
	}

	static Result<void> AssetDeserialize(BonReader reader, ValueView value, BonEnvironment environment)//, DeserializeFieldState state)
	{
		Log.EngineLogger.Assert(value.type == typeof(Asset));

		String identifier = scope .();

		Deserialize.String!(reader, ref identifier, environment);

		Asset asset = Application.Get().ContentManager.LoadAsset(identifier);

		if (asset != null)
		{
			Asset oldAsset = value.Get<Asset>();
			oldAsset.ReleaseRef();

			value.Assign(asset);
			return .Ok;
		}
		else
		{
			Deserialize.Error!("Invalid resource path", reader, value.type);
		}
	}

	//gBonEnv.typeHandlers.Add(typeof(Resource<>),
	//    ((.)new => ResourceSerialize, (.)new => ResourceDeserialize));
}