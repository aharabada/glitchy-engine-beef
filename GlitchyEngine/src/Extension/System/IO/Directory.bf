namespace System.IO;

extension Directory
{
	[Import("Shlwapi.lib"), CLink, CallingConvention(.Stdcall)]
	private static extern System.Windows.IntBool PathIsDirectoryEmptyW(char16* pszPath);

	public static bool IsEmpty(StringView fileName)
	{
		// TODO: This is obviously windows only
		return PathIsDirectoryEmptyW(fileName.ToScopedNativeWChar!());
	}

	public static Result<void, Platform.BfpFileResult> Copy(StringView fromPath, StringView toPath)
	{
		if (fromPath.Length <= 2)
			return .Err(.InvalidParameter);
		if ((fromPath[0] != '/') && (fromPath[0] != '\\'))
		{
			if (fromPath[1] == ':')
			{
				if (fromPath.Length < 3)
					return .Err(.InvalidParameter);
			}
		}

		if (!Directory.Exists(fromPath))
			return .Err(.NotFound);

		Try!(Directory.CreateDirectory(toPath));

	    for (var directoryEntry in Directory.EnumerateDirectories(fromPath))
	    {
			let dirFromPath = scope String();
			directoryEntry.GetFilePath(dirFromPath);

			let dirName = scope String();
			directoryEntry.GetFileName(dirName);

			let dirToPath = scope String();
			Path.Combine(dirToPath, toPath, dirName);

			Try!(Copy(dirFromPath, dirToPath));
	    }
		
		for (var fileEntry in Directory.EnumerateFiles(fromPath))
		{
			let fileFromPath = scope String();
			fileEntry.GetFilePath(fileFromPath);

			let fileName = scope String();
			fileEntry.GetFileName(fileName);

			let fileToPath = scope String();
			Path.Combine(fileToPath, toPath, fileName);

			Try!(File.Copy(fileFromPath, fileToPath));
		}

		return .Ok;
	}
}