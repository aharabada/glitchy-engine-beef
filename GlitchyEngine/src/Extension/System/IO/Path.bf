using System.Diagnostics;

namespace System.IO;

extension Path
{
	public static mixin GetScopedFullPath(String path)
	{
		String fullPath = scope:: String(Path.MaxPath);
		Path.GetFullPath(path, fullPath);

		fullPath
	}

	/// Opens the file browser and selects the specified file.
	/// @param path The path of the file to select.
	public static extern Result<void> OpenFolderAndSelectItem(String path);

	/// Opens the file browser in the given directory.
	/// @param directory The directory to show in the file browser.
	public static extern Result<void> OpenFolder(String directory);

	/// Shows a dialog in which the user can select which program to open the given file with.
	/// @param The Path of the file to open.
	public static extern Result<void> OpenWithDialog(String filePath);

	public static void Fixup(String path)
	{
		path.Replace(AltDirectorySeparatorChar, DirectorySeparatorChar);
		path.Replace(scope $".{DirectorySeparatorChar}", "");
		path.Replace(scope $"{DirectorySeparatorChar}.", "");

		if (path.StartsWith(DirectorySeparatorChar))
			path.Remove(0, 1);
	}

	public static void Combine(String target, params StringView[] components)
	{
		for (var component in components)
		{
			if ((target.Length > 0) && (!target.EndsWith("\\")) && (!target.EndsWith("/")) &&
				(!component.StartsWith("\\")) && (!component.StartsWith("/")))
				target.Append(Path.DirectorySeparatorChar);
			target.Append(component);
		}

		target.Replace(Path.AltDirectorySeparatorChar, Path.DirectorySeparatorChar);
	}
}