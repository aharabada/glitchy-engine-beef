using GlitchyEngine.Core;
using System;

namespace GlitchyEngine.Content;

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

	protected ~this()
	{
		// TODO: crash when _contentManager is deleted first...
		// TODO: unregister from content manager
		_contentManager?.UnmanageAsset(this);
	}
}