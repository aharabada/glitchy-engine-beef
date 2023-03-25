#if BF_PLATFORM_WINDOWS

using DirectX.Common;
using DirectX.Windows;
using System;
using System.Diagnostics;
using DirectX.Windows.Winuser;

namespace DirectX.Windows.Winuser
{
	enum OpenAsInfoFlags : uint32
	{
		/// Enable the "always use this program" checkbox. If not passed, it will be disabled.
		AllowRegistration = 0x1,
		/// Do the registration after the user hits the OK button.
		RegisterExtension = 0x2,
		/// Execute file after registering.
		Exec = 0x4,
		///Force the Always use this program checkbox to be checked.
		/// Typically, you won't use the OAIF_ALLOW_REGISTRATION flag when you pass this value.
		ForceRegistration = 0x8,
		/// Introduced in Windows Vista. Hide the Always use this program checkbox. If this flag is specified, the OAIF_ALLOW_REGISTRATION and OAIF_FORCE_REGISTRATION flags will be ignored.
		HideRegistration = 0x20,
		/// Introduced in Windows Vista. The value for the extension that is passed is actually a protocol, so the Open With dialog box should show applications that are registered as capable of handling that protocol.
		UrlProtocol = 0x40,
		/// Introduced in Windows 8. The location pointed to by the pcszFile parameter is given as a URI.
		FileIsUri = 0x80
	}

	struct OpenAsInfo
	{
		public LPCWSTR File;
		public LPCWSTR Class;
		public OpenAsInfoFlags Flags;
	}

	static
	{
		[Import("user32.lib"), CallingConvention(.Stdcall), CLink]
		public extern static HResult SHOpenWithDialog(HWND hwndParent, OpenAsInfo* poainfo);
	}
}

namespace System.IO;

extension Path
{
	/// Opens the file browser and selects the specified file.
	/// @param path The path of the file to select.
	public static override Result<void> OpenFolderAndSelectItem(String path)
	{
		String fullPath = GetScopedFullPath!(path);

		ProcessStartInfo processInfo = scope .();
		processInfo.SetFileNameAndArguments(scope $"explorer /select,\"{fullPath}\"");

		return scope SpawnedProcess().Start(processInfo);
	}
	
	/// Opens the file browser in the given directory.
	/// @param directory The directory to show in the file browser.
	public static override Result<void> OpenFolder(String directory)
	{
		String fullPath = GetScopedFullPath!(directory);

		ProcessStartInfo processInfo = scope .();
		processInfo.SetFileNameAndArguments(scope $"explorer \"{fullPath}\"");

		return scope SpawnedProcess().Start(processInfo);
	}

	public static override Result<void> OpenWithDialog(String filePath)
	{
		String fullPath = GetScopedFullPath!(filePath);

		OpenAsInfo info = .();
		info.File = fullPath.ToScopedNativeWChar!();
		info.Class = null;
		info.Flags = .Exec;

		HResult result = SHOpenWithDialog(0, &info);

		if (result.Succeeded)
			return .Ok;
		else
			return .Err;
	}
}

#endif
