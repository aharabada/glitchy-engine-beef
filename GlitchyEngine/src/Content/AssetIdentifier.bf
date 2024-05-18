using System;

namespace GlitchyEngine.Content;

public class AssetIdentifier
{
	private String _fullIdentifier ~ delete:append _;

	private int _subassetSeperator;

	public StringView FullIdentifier => _fullIdentifier;
	public StringView AssetIdentifier => _subassetSeperator > 0 ? StringView(_fullIdentifier, 0, _subassetSeperator) : _fullIdentifier;
	public StringView SubassetIdentifier => _subassetSeperator > 0 ? StringView(_fullIdentifier, _subassetSeperator + 1) : .();

	[AllowAppend]
	public this(StringView assetIdentifier)
	{
		String identifier = append String(assetIdentifier);
		_fullIdentifier = identifier;

		Fixup(_fullIdentifier);

		_subassetSeperator = _fullIdentifier.IndexOf(':', 0);
	}

	[AllowAppend]
	public this(StringView assetIdentifier, StringView subAssetIdentifier)
	{
		String identifier = append String(assetIdentifier.Length + 1 + subAssetIdentifier.Length);
		identifier.AppendF($"{assetIdentifier}:{subAssetIdentifier}");

		Fixup(identifier);

		_subassetSeperator = _fullIdentifier.IndexOf(':', 0);

	}

	public static StringView operator implicit(AssetIdentifier identifier) => identifier.FullIdentifier;

	public const char8 DirectorySeparatorChar = '/';

	/// Removes or unifies potential platform specific or file-path related stuff in the given asset identifier
	public static void Fixup(String assetIdentifier)
	{
		int dotIndex = 0;

		assetIdentifier.Replace('\\', DirectorySeparatorChar);
		
		// Replace /./ stuff
		while ((dotIndex = assetIdentifier.IndexOf('.', dotIndex)) != -1)
		{
			char8 lastChar = '\0';
			char8 nextChar = '\0';

			int nextIndex = dotIndex + 1;
			if (nextIndex < assetIdentifier.Length)
				nextChar = assetIdentifier[nextIndex];

			int lastIndex = dotIndex - 1;
			if (lastIndex < assetIdentifier.Length)
				lastChar = assetIdentifier[nextIndex];

			// We either need to have a slash on both sides, or we have to be at the start or end of the string
			if ((lastChar == '\0' || lastChar == DirectorySeparatorChar) &&
				(lastChar == '\0' || lastChar == DirectorySeparatorChar))
			{
				if (lastChar != '\0')
					assetIdentifier.Remove(lastIndex, 2);
				else
					assetIdentifier.Remove(dotIndex, 2);
			}
			else
			{
				// Skip the dot
				dotIndex++;
			}
		}

		if (assetIdentifier.StartsWith(DirectorySeparatorChar))
			assetIdentifier.Remove(0, 1);

		assetIdentifier.EnsureNullTerminator();
	}
}
