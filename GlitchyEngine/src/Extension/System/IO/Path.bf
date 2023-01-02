using System.Diagnostics;
namespace System.IO;

extension Path
{
	/// Opens the file browser and selects the specified file.
	/// @param path The path of the file to select.
	public static void OpenFolderAndSelectItem(String path)
	{
		String fullPath = scope String(256);
		Path.GetFullPath(path, fullPath);

#if BF_PLATFORM_WINDOWS
		ProcessStartInfo processInfo = scope .();
		processInfo.SetFileNameAndArguments(scope $"explorer /select,\"{fullPath}\"");

		scope SpawnedProcess().Start(processInfo);
#else
		Runtime.NotImplemented();
#endif
	}

	/// Opens the file browser in the given directory.
	/// @param directory The directory to show in the file browser.
	public static void OpenFolder(String directory)
	{
		String fullPath = scope String(256);
		Path.GetFullPath(directory, fullPath);

#if BF_PLATFORM_WINDOWS
		ProcessStartInfo processInfo = scope .();
		processInfo.SetFileNameAndArguments(scope $"explorer \"{fullPath}\"");

		scope SpawnedProcess().Start(processInfo);
#else
		Runtime.NotImplemented();
#endif
	}
}