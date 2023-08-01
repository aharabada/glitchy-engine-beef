using GlitchyEngine.Core;
using System;
using Bon;
using Bon.Integrated;
using System.Reflection;
using System.IO;

namespace GlitchyEngine.Content;

[BonTarget]
abstract class Asset : RefCounter
{
	internal AssetHandle _handle = .Invalid;

	private append String _identifier;

	internal IContentManager _contentManager;

	/// Gets the identifier of this asset.
	/// @remarks The identifier is the name with which the asset was registered in the content manager.
	/// 	This identifier can be used to request the Asset from the content manager.
	public StringView Identifier
	{
		get => _identifier;
		internal set => _identifier.Set(value);
	}

	/// If true the asset is completely loaded. If false it is only partially loaded (if at all).
	public bool Complete { get; internal set; }

	// TODO: do we need unmanaged assets? Probably not...
	/// Gets the content manager that manages this asset; or null if this asset isn't managed.
	public IContentManager ContentManager => _contentManager;

	public AssetHandle Handle => _handle;

	static this
	{
		gBonEnv.typeHandlers.Add(typeof(Asset),
			    ((.)new => AssetSerialize, new => AssetDeserialize));
	}

	protected ~this()
	{
		// TODO: crash when _contentManager is deleted first...
		// TODO: unregister from content manager
		//_contentManager?.UnmanageAsset(this);
	}

	static void AssetSerialize(BonWriter writer, ValueView value, BonEnvironment environment, SerializeValueState state)
	{
		Log.EngineLogger.Assert(value.type == typeof(Asset));
		
		var handle = value.Get<Asset>()._handle;
		Serialize.Value(writer, handle, environment);


		//AssetHandle.[Friend]AssetSerialize(writer, ValueView(typeof(AssetHandle), &handle), environment, state);

	    //writer.String(identifier);
	}

	static Result<void> AssetDeserialize(BonReader reader, ValueView value, BonEnvironment environment, DeserializeValueState state)
	{
		Log.EngineLogger.Assert(value.type == typeof(Asset));

		Try!(Deserialize.Value<AssetHandle>(reader, let handle, environment));

		//String identifier = scope .();

		//Deserialize.String!(reader, ref identifier, environment);

		AssetHandle loadedHandle = Content.LoadAsset(handle);

		if (loadedHandle == .Invalid)
		{
			value.Assign<Asset>(null);
			return .Ok;
		}

		Asset asset = Content.GetAsset<Asset>(handle);

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

		/*String identifier = scope .();

		Deserialize.String!(reader, ref identifier, environment);

		AssetHandle handle = Content.LoadAsset(identifier);

		if (handle == .Invalid)
		{
			value.Assign<Asset>(null);
			return .Ok;
		}

		Asset asset = Content.GetAsset<Asset>(handle);

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
		}*/
	}

	//gBonEnv.typeHandlers.Add(typeof(Resource<>),
	//    ((.)new => ResourceSerialize, (.)new => ResourceDeserialize));
}