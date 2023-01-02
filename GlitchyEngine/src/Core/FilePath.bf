using System;
using System.IO;

namespace GlitchyEngine.Core;

// TODO: make usable
class FilePath : IHashable
{
	append String _path = .();

	public bool IsRooted => Path.IsPathRooted(_path);

	public this()
	{

	}

	public this(StringView path)
	{
		Set(path);
	}

	public static implicit operator StringView(FilePath filePath) => filePath._path;
	
	/// @param fixDirectorySeperators If true all alternative directory seperators will be replaced by the primary seperator.
	/// @param resolveRelativeDirectories If true relative directories ('.' and '..') will be removed from the path.
	public enum CanonicalizationFlags
	{
		FixDirectorySeperators = 1,
		ResolveRelativeDirectories = _ << 1,
		MakeFullPath = _ << 1
	}

	public void Set(StringView path, CanonicalizationFlags canonicalizationFlags = .FixDirectorySeperators | .ResolveRelativeDirectories)
	{
		_path.Append(path);
		Canonicalize(canonicalizationFlags);
	}

	/// Converts the path to a canonicalized path.
	public void Canonicalize(CanonicalizationFlags canonicalizationFlags = .FixDirectorySeperators | .ResolveRelativeDirectories)
	{
		if (canonicalizationFlags.HasFlag(.FixDirectorySeperators))
		{
			FixDirectorySeperators();	
		}

		if (canonicalizationFlags.HasFlag(.ResolveRelativeDirectories))
		{
			ResolveRelativeDirectories();
		}

		if (canonicalizationFlags.HasFlag(.MakeFullPath))
		{
			MakeFullPath();
		}
	}

	public void MakeFullPath()
	{
		if (IsRooted)
			return;

		String buffer = scope String(Path.[Friend]MaxPath);

		Path.GetFullPath(_path, buffer);

		_path..Clear().Append(buffer);
	}

	public void FixDirectorySeperators()
	{
		_path.Replace(Path.AltDirectorySeparatorChar, Path.DirectorySeparatorChar);
	}

	public void ResolveRelativeDirectories()
	{
		//	find .
		//		find entire entry name
		//		remove entry name (if its only .)

		/*for (char32 c in _path.DecodedChars)
		{
			if (c == '.')
			{
			}
		}

		for (StringView component in _path.Split(Path.DirectorySeparatorChar))
		{
			if (component == ".")
			{
				// . can be removed without replacement
			}
			else if (component == "..")
			{
				// .. can only be removed when not at the start of after another ..

				// e.g. "../foo" and "../../foo" can't be changed
				// but "foo/.." can become "foo"
				// "foo/../.." can become ".."
			}
		}*/
	}

	public void Append(StringView newPath)
	{

	}

	public int GetHashCode() => _path.GetHashCode();
}