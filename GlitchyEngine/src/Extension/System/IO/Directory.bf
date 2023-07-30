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
}