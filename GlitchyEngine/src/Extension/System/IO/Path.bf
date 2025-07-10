using System.Diagnostics;
using System.Collections;

namespace System.IO;

extension Path
{
	public static mixin GetScopedFullPath(StringView path)
	{
		String fullPath = scope:: String(Path.MaxPath);
		Path.GetFullPath(path, fullPath);

		fullPath
	}

	/// Opens the file browser and selects the specified file.
	/// @param path The path of the file to select.
	public static extern Result<void> OpenFolderAndSelectItem(StringView path);

	/// Opens the file browser in the given directory.
	/// @param directory The directory to show in the file browser.
	public static extern Result<void> OpenFolder(StringView directory);

	/// Shows a dialog in which the user can select which program to open the given file with.
	/// @param The Path of the file to open.
	public static extern Result<void> OpenWithDialog(StringView filePath);

	public static void Fixup(String path)
	{
		path.Replace(AltDirectorySeparatorChar, DirectorySeparatorChar);
		path.Replace(scope $".{DirectorySeparatorChar}", "");
		path.Replace(scope $"{DirectorySeparatorChar}.", "");

		if (path.StartsWith(DirectorySeparatorChar))
			path.Remove(0, 1);
	}

	// Compared to the original Combine, this one makes sure we don't add multiple seperators. Also makes sure, the path contains only the main Separator char.
	new public static void Combine(String target, params StringView[] components)
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

	/**
	 * If a file with the given path ([targetDirectory]/[wantedName][fileExtension]) already exists it will add a number at the end of the file name.
	 * @param targetDirectory The directory in which the file will be put.
	 * @param wantedFileName The wanted name of the file. If it already exists a number will be put behind it.
	 * @param fileExtension The file extension. This should contain the dot.
	 * @param outFreePath The string that will contain the resulting filepath. Note: This will be cleared before writing the file name.
	 * @param outFreeFilename Optional, if set to a string, the final file name that is free will be stored in this varialbe.
	 * @param blockedPaths Optional, can be used to provide a collection of paths that will be considered as existing.
	 */
	public static void FindFreePath(StringView targetDirectory, StringView wantedName, StringView fileExtension, String outFreePath, String outFreeFilename = null, ICollection<StringView> blockedPaths = null)
	{
		int fileNumber = 0;

		String wantedNameCopy = new:ScopedAlloc! .(wantedName);

		String currentFileName = outFreeFilename ?? scope .();
		currentFileName.SetF($"{wantedNameCopy}{fileExtension}");
		while (true)
		{
			Path.Combine(outFreePath..Clear(), targetDirectory, currentFileName);
			
			if (!File.Exists(outFreePath) && !Directory.Exists(outFreePath) && !(blockedPaths?.Contains(outFreePath) ?? false))
				break;

			fileNumber++;
			currentFileName.SetF($"{wantedNameCopy} ({fileNumber}){fileExtension}");
		}
	}
}