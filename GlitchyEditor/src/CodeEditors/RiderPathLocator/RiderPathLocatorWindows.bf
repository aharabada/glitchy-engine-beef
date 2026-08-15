// Windows implementation of the RiderPathLocator, see RiderPathLocator.bf for the platform independent part and the license of the original code.

#if BF_PLATFORM_WINDOWS

using System;
using System.Collections;
using System.IO;
using System.Text;

namespace GlitchyEditor.CodeEditors;

extension RiderPathLocator
{
	private const String RiderExecutableName = "rider64.exe";

	/// The maximum length of a registry key name.
	private const int MaxRegistryKeyNameLength = 255;

	[Import("advapi32.lib"), CLink, CallingConvention(.Stdcall)]
	private static extern int32 RegEnumKeyExW(Windows.HKey hKey, uint32 dwIndex, char16* lpName,
		uint32* lpcchName, uint32* lpReserved, char16* lpClass, uint32* lpcchClass,
		void* lpftLastWriteTime);

	protected static override StringView GetRiderExecutableName() => RiderExecutableName;

	public static override Result<RiderInstallInfo> GetInstallInfoFromRiderPath(StringView riderExePath, RiderInstallType installType)
	{
		if (!File.Exists(riderExePath))
			return .Err;

		String riderDirectory = scope .();
		Try!(GetRiderDirectory(riderExePath, riderDirectory));

		RiderVersion version = .();

		String installName = scope .();
		String installVersion = scope .();

		String productInfoPath = scope .();
		Path.Combine(productInfoPath, riderDirectory, "product-info.json");

		if (File.Exists(productInfoPath))
			version = ParseProductInfoJson(productInfoPath, installName, installVersion);
		else
		{
			installName.Set("Rider");
			version.ToString(installVersion..Clear());
		}

		if (!version.IsInitialized)
		{
			// Toolbox installations are laid out as "<...>/<build number>/bin/rider64.exe",
			// so the name of the installation directory is the version.
			String directoryName = scope .();
			Path.GetFileName(riderDirectory, directoryName);

			version = RiderVersion.Parse(directoryName);
		}

		return new RiderInstallInfo(riderExePath, version, installType, scope $"{installName} {installVersion}");
	}

	public static override void CollectAllPaths(List<RiderInstallInfo> outInstalls)
	{
		const String UninstallKey = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall";
		const String UninstallKey32 = @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall";
		const String RiderKey = @"SOFTWARE\JetBrains\Rider";
		const String RiderKey32 = @"SOFTWARE\WOW6432Node\JetBrains\Rider";

		List<RiderInstallInfo> found = scope .();
		// Everything that isn't moved into outInstalls (i.e. the duplicates) is deleted here.
		defer { ClearAndDeleteItems!(found); }

		// Regular installations register themselves in the uninstall list.
		CollectPathsFromRegistry(Windows.HKEY_CURRENT_USER, UninstallKey, "InstallLocation", "Rider", found);
		CollectPathsFromRegistry(Windows.HKEY_LOCAL_MACHINE, UninstallKey, "InstallLocation", "Rider", found);
		CollectPathsFromRegistry(Windows.HKEY_CURRENT_USER, UninstallKey32, "InstallLocation", "Rider", found);
		CollectPathsFromRegistry(Windows.HKEY_LOCAL_MACHINE, UninstallKey32, "InstallLocation", "Rider", found);

		// dotUltimate installations use their own key.
		CollectPathsFromRegistry(Windows.HKEY_CURRENT_USER, RiderKey, "InstallDir", "", found);
		CollectPathsFromRegistry(Windows.HKEY_LOCAL_MACHINE, RiderKey, "InstallDir", "", found);
		CollectPathsFromRegistry(Windows.HKEY_CURRENT_USER, RiderKey32, "InstallDir", "", found);
		CollectPathsFromRegistry(Windows.HKEY_LOCAL_MACHINE, RiderKey32, "InstallDir", "", found);

		// Toolbox installations aren't registered anywhere, we have to go looking for them.
		String defaultToolboxPath = scope .();
		if (GetToolboxPathFromEnvironment(defaultToolboxPath) case .Ok)
			CollectPathsFromToolbox(defaultToolboxPath, found);

		CollectPathsFromToolboxRegistry(Windows.HKEY_CURRENT_USER, @"Software\JetBrains\Toolbox\", found);
		CollectPathsFromToolboxRegistry(Windows.HKEY_LOCAL_MACHINE, @"Software\JetBrains\Toolbox\", found);
		CollectPathsFromToolboxRegistry(Windows.HKEY_CURRENT_USER, @"Software\JetBrains s.r.o.\JetBrainsToolbox\", found);
		CollectPathsFromToolboxRegistry(Windows.HKEY_LOCAL_MACHINE, @"Software\JetBrains s.r.o.\JetBrainsToolbox\", found);

		DeduplicateAndSort(found, outInstalls);
	}

	/// Enumerates the subkeys of the given registry key and creates an installation info for
	/// every subkey that points at a Rider installation.
	/// @param rootKey The registry hive to look in.
	/// @param subKeyPath The key whose subkeys will be enumerated.
	/// @param valueName The name of the value that holds the installation directory.
	/// @param keyNameFilter If not empty, only subkeys whose name contains this string are looked at.
	private static void CollectPathsFromRegistry(Windows.HKey rootKey, StringView subKeyPath,
		StringView valueName, StringView keyNameFilter, List<RiderInstallInfo> outInstalls)
	{
		Windows.HKey key;
		if (Windows.RegOpenKeyExW(rootKey, subKeyPath.ToScopedNativeWChar!(), 0, (.)Windows.KEY_READ, out key) != Windows.ERROR_SUCCESS)
			return;

		defer Windows.RegCloseKey(key);

		List<String> subKeyNames = scope .();
		defer { ClearAndDeleteItems!(subKeyNames); }

		if (EnumerateSubKeys(key, subKeyNames) case .Err)
			return;

		// All of these are reused across the iterations: a "scope" allocation inside a loop body
		// lives until the enclosing method returns, and the uninstall key has hundreds of subkeys.
		char16[MaxRegistryKeyNameLength + 1] subKeyNameBuffer = ?;
		String installLocation = scope .();
		String exePath = scope .();

		for (String subKeyName in subKeyNames)
		{
			if (!keyNameFilter.IsEmpty && !subKeyName.Contains(keyNameFilter))
				continue;

			int encodedLength = UTF16.GetEncodedLen(subKeyName);
			if (encodedLength > MaxRegistryKeyNameLength)
				continue;

			UTF16.Encode(subKeyName, &subKeyNameBuffer, encodedLength).IgnoreError();
			subKeyNameBuffer[encodedLength] = 0;

			Windows.HKey subKey;
			if (Windows.RegOpenKeyExW(key, &subKeyNameBuffer, 0, (.)Windows.KEY_READ, out subKey) != Windows.ERROR_SUCCESS)
				continue;

			installLocation.Clear();
			Result<void> valueResult = subKey.GetValue(valueName, installLocation);

			Windows.RegCloseKey(subKey);

			if (valueResult case .Err)
				continue;

			if (installLocation.IsWhiteSpace)
				continue;

			exePath.Clear();
			Path.Combine(exePath, installLocation, "bin", RiderExecutableName);

			if (GetInstallInfoFromRiderPath(exePath, .Installed) case .Ok(let installInfo))
				outInstalls.Add(installInfo);
		}
	}

	/// Enumerates the names of all subkeys of the given registry key.
	/// @remarks Windows.HKey.EnumValue enumerates values (and is unimplemented), there is no
	///          counterpart for subkeys in corlib.
	private static Result<void> EnumerateSubKeys(Windows.HKey key, List<String> outNames)
	{
		// Reused across the iterations, see the note in CollectPathsFromRegistry.
		char16[MaxRegistryKeyNameLength + 1] nameBuffer = ?;

		for (uint32 index = 0; true; index++)
		{
			uint32 nameLength = nameBuffer.Count;

			int32 result = RegEnumKeyExW(key, index, &nameBuffer, &nameLength, null, null, null, null);

			if (result == Windows.ERROR_NO_MORE_ITEMS)
				break;

			if (result != Windows.ERROR_SUCCESS)
				return .Err;

			// RegEnumKeyExW null-terminates, but be explicit about it since we reuse the buffer.
			nameBuffer[Math.Min((int)nameLength, MaxRegistryKeyNameLength)] = 0;

			outNames.Add(new String(&nameBuffer));
		}

		return .Ok;
	}

	/// Gets the default location of the JetBrains Toolbox ("%LOCALAPPDATA%/JetBrains/Toolbox").
	private static Result<void> GetToolboxPathFromEnvironment(String outPath)
	{
		String localAppData = scope .();
		Try!(Environment.GetEnvironmentVariable("LOCALAPPDATA", localAppData));

		Path.Combine(outPath, localAppData, "JetBrains", "Toolbox");

		return .Ok;
	}

	protected static override Result<void> GetDefaultIdeInstallLocationForToolboxV2(String outPath)
	{
		String localAppData = scope .();
		Try!(Environment.GetEnvironmentVariable("LOCALAPPDATA", localAppData));

		Path.Combine(outPath, localAppData, "Programs");

		return .Ok;
	}

	/// Looks up the location of the JetBrains Toolbox in the registry and collects the Rider
	/// installations it manages.
	private static void CollectPathsFromToolboxRegistry(Windows.HKey rootKey, StringView subKeyPath, List<RiderInstallInfo> outInstalls)
	{
		Windows.HKey key;
		if (Windows.RegOpenKeyExW(rootKey, subKeyPath.ToScopedNativeWChar!(), 0, (.)Windows.KEY_READ, out key) != Windows.ERROR_SUCCESS)
			return;

		defer Windows.RegCloseKey(key);

		// The default value of the key contains the path of the Toolbox' "bin" directory.
		String toolboxBinPath = scope .();
		if (key.GetValue("", toolboxBinPath) case .Err)
			return;

		if (toolboxBinPath.IsWhiteSpace)
			return;

		String binDirectoryName = scope .();
		Path.GetFileName(toolboxBinPath, binDirectoryName);

		if (StringView.Compare(binDirectoryName, "bin", true) != 0)
			return;

		String toolboxPath = scope .();
		if (Path.GetDirectoryPath(toolboxBinPath, toolboxPath) case .Err)
			return;

		CollectPathsFromToolbox(toolboxPath, outInstalls);
	}
}

#endif
