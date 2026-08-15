// Beef port of JetBrains "Rider Source Code Access":
//   https://github.com/JetBrains/RiderSourceCodeAccess/tree/main/Source/RiderSourceCodeAccess/Private/RiderPathLocator
//
// Copyright Epic Games, Inc. All Rights Reserved.
// Licensed under the Apache License, Version 2.0 - see LICENSE-RiderPathLocator.txt
//
// Changes from the original: rewritten in Beef against corlib instead of the
// Unreal Engine types (FString/TArray/TOptional/FPaths/FRegexPattern/FJsonSerializer/...).
// The "plugins/rider-cpp" requirement, the ESupportUproject state and the
// RiderLocations.txt resource-file lookup were removed because they only make sense for Unreal projects.
//
// This file holds the platform independent part, the platform specific parts live in the extensions (e.g. RiderPathLocatorWindows.bf).

using System;
using System.Collections;
using System.IO;
using Beefy.utils;

namespace GlitchyEditor.CodeEditors;

/// A dot-separated version number, e.g. "2024.1.2" or the build number "241.15989.155".
struct RiderVersion : IHashable
{
	public const int32 InvalidVersion = -1;

	private const int32 MaxParts = 4;

	private int32[MaxParts] _parts;
	private int32 _count;

	public bool IsInitialized => _count != 0;

	public int32 Major => _count >= 1 ? _parts[0] : InvalidVersion;
	public int32 Minor => _count >= 2 ? _parts[1] : InvalidVersion;
	public int32 Patch => _count >= 3 ? _parts[2] : InvalidVersion;

	public static RiderVersion Parse(StringView versionString)
	{
		RiderVersion version = .();

		for (StringView part in versionString.Split('.'))
		{
			if (version._count >= MaxParts)
				break;

			// Note: the original uses FCString::Atoi, which yields 0 for garbage instead of failing.
			int32 value = 0;
			if (int32.Parse(part) case .Ok(let parsedValue))
				value = parsedValue;

			version._parts[version._count] = value;
			version._count++;
		}

		return version;
	}

	/// Compares two versions element by element.
	/// @returns A negative value if lhs is older than rhs, a positive value if it is newer; otherwise 0.
	public static int Compare(Self lhs, Self rhs)
	{
		int32 sharedCount = Math.Min(lhs._count, rhs._count);

		for (int32 i < sharedCount)
		{
			if (lhs._parts[i] != rhs._parts[i])
				return lhs._parts[i] < rhs._parts[i] ? -1 : 1;
		}

		// Equal prefix: the shorter version is the older one, so that "5.0" is older than "5.0.1".
		return lhs._count <=> rhs._count;
	}

	public static bool operator<(Self lhs, Self rhs) => Compare(lhs, rhs) < 0;

	public static bool operator==(Self lhs, Self rhs) => Compare(lhs, rhs) == 0;

	public static bool operator!=(Self lhs, Self rhs) => Compare(lhs, rhs) != 0;

	public int GetHashCode()
	{
		int hash = 0;

		for (int32 i < _count)
			hash = (hash * 31) + (int)_parts[i];

		return hash;
	}

	public override void ToString(String strBuffer)
	{
		if (_count == 0)
		{
			strBuffer.Append("<unknown>");
			return;
		}

		for (int32 i < _count)
		{
			if (i != 0)
				strBuffer.Append('.');

			_parts[i].ToString(strBuffer);
		}
	}
}

/// How a Rider installation was set up.
enum RiderInstallType
{
	/// Installed by the regular Rider installer.
	Installed,
	/// Installed through the JetBrains Toolbox.
	Toolbox,
	/// Provided by the user.
	Custom
}

/// A single Rider installation found on this machine.
class RiderInstallInfo
{
	/// The full path of the Rider executable (rider64.exe).
	public String Path ~ delete _;
	public RiderVersion Version;
	public RiderInstallType InstallType;
	public String Name ~ delete _;

	public this(StringView path, RiderVersion version, RiderInstallType installType, StringView name)
	{
		Path = new String(path);
		Version = version;
		InstallType = installType;
		Name = new String(name);
	}
}

/// Locates the JetBrains Rider installations on this machine.
static class RiderPathLocator
{
	/// Maximum directory depth we descend into while looking for the Rider executable.
	/// The original search is unbounded, but it searches locations like "%LOCALAPPDATA%/Programs".
	protected const int MaxSearchDepth = 8;
	/// Maximum number of directories visited by a single recursive search.
	protected const int MaxSearchedDirectories = 4096;

	/// Creates the installation info for the given Rider executable.
	/// @param riderExePath The path of a rider64.exe.
	/// @returns The installation info; or .Err if the given path is not a usable Rider installation.
	public static extern Result<RiderInstallInfo> GetInstallInfoFromRiderPath(StringView riderExePath, RiderInstallType installType);

	/// Collects every Rider installation that can be found on this machine.
	/// The entries are deduplicated by path and sorted, newest version first.
	/// @param outInstalls Receives the installations. The caller takes ownership of the entries.
	public static extern void CollectAllPaths(List<RiderInstallInfo> outInstalls);

	/// Gets the file name of the Rider executable on this platform (e.g. "rider64.exe").
	protected static extern StringView GetRiderExecutableName();

	/// Gets the default location the Toolbox V2 installs IDEs into.
	protected static extern Result<void> GetDefaultIdeInstallLocationForToolboxV2(String outPath);

	/// Moves the located installations into outInstalls, dropping the ones that were found more
	/// than once, and sorts them so that the newest installation comes first.
	/// @param found The located installations. The entries are moved into outInstalls or deleted.
	/// @param outInstalls Receives the installations. The caller takes ownership of the entries.
	protected static void DeduplicateAndSort(List<RiderInstallInfo> found, List<RiderInstallInfo> outInstalls)
	{
		// The same installation usually shows up through more than one source.
		for (int i < found.Count)
		{
			RiderInstallInfo install = found[i];

			bool isDuplicate = false;

			for (RiderInstallInfo existing in outInstalls)
			{
				if (IsSamePath(existing.Path, install.Path))
				{
					isDuplicate = true;
					break;
				}
			}

			if (isDuplicate)
				continue;

			outInstalls.Add(install);
			// Ownership moved to outInstalls, make sure the caller's cleanup doesn't delete it.
			found[i] = null;
		}

		// Newest first, so that the caller can simply take the first entry.
		outInstalls.Sort(scope (lhs, rhs) => RiderVersion.Compare(rhs.Version, lhs.Version));
	}

	/// Gets the installation directory of Rider from the path of its executable.
	/// The executable is expected to live in a "bin" directory, i.e. "<riderDirectory>/bin/rider64.exe".
	protected static Result<void> GetRiderDirectory(StringView riderExePath, String outDirectory)
	{
		// The original matches the regex "(.*)(?:\\|/)bin" against the executable path,
		// which is the same as taking the grandparent directory of a file inside "bin".
		String binDirectory = scope .();
		Try!(Path.GetDirectoryPath(riderExePath, binDirectory));

		String binDirectoryName = scope .();
		Path.GetFileName(binDirectory, binDirectoryName);

		if (StringView.Compare(binDirectoryName, "bin", true) != 0)
			return .Err;

		return Path.GetDirectoryPath(binDirectory, outDirectory);
	}

	/// Compares two paths, ignoring case and the difference between the directory separators.
	protected static bool IsSamePath(StringView left, StringView right)
	{
		if (left.Length != right.Length)
			return false;

		for (int i < left.Length)
		{
			char8 leftChar = left[i];
			char8 rightChar = right[i];

			if (Path.IsDirectorySeparatorChar(leftChar) && Path.IsDirectorySeparatorChar(rightChar))
				continue;

			if (leftChar.ToLower != rightChar.ToLower)
				return false;
		}

		return true;
	}

	/// Collects the Rider installations managed by the JetBrains Toolbox at the given location.
	protected static void CollectPathsFromToolbox(StringView toolboxPath, List<RiderInstallInfo> outInstalls)
	{
		if (toolboxPath.IsEmpty || !Directory.Exists(toolboxPath))
			return;

		String customInstallLocation = scope .();
		ExtractPathFromSettingsJson(toolboxPath, customInstallLocation);

		if (!customInstallLocation.IsEmpty)
		{
			// Toolbox V1 puts the IDEs into an "apps" subdirectory of the install location.
			String appsPath = scope .();
			Path.Combine(appsPath, customInstallLocation, "apps");

			int countBefore = outInstalls.Count;
			CollectPathsFromToolboxDirectory(appsPath, outInstalls);

			if (outInstalls.Count != countBefore)
				return;

			// Toolbox V2 puts them directly into the install location.
			CollectPathsFromToolboxDirectory(customInstallLocation, outInstalls);

			return;
		}

		// Toolbox V1 default install location.
		String defaultAppsPath = scope .();
		Path.Combine(defaultAppsPath, toolboxPath, "apps");

		int countBefore = outInstalls.Count;
		CollectPathsFromToolboxDirectory(defaultAppsPath, outInstalls);

		if (outInstalls.Count != countBefore)
			return;

		// Toolbox V2 default install location.
		String defaultInstallLocation = scope .();
		if (GetDefaultIdeInstallLocationForToolboxV2(defaultInstallLocation) case .Ok)
			CollectPathsFromToolboxDirectory(defaultInstallLocation, outInstalls);
	}

	/// Searches the given directory for Rider executables and creates the installation infos for them.
	protected static void CollectPathsFromToolboxDirectory(StringView toolboxRiderRootPath, List<RiderInstallInfo> outInstalls)
	{
		if (toolboxRiderRootPath.IsEmpty || !Directory.Exists(toolboxRiderRootPath))
			return;

		List<String> riderPaths = scope .();
		defer { ClearAndDeleteItems!(riderPaths); }

		int searchedDirectories = 0;
		FindFilesRecursive(toolboxRiderRootPath, GetRiderExecutableName(), riderPaths, MaxSearchDepth, ref searchedDirectories);

		// Reused across the iterations, see the note in FindFilesRecursive.
		String historyJsonPath = scope .();

		for (String riderPath in riderPaths)
		{
			if (!(GetInstallInfoFromRiderPath(riderPath, .Toolbox) case .Ok(let installInfo)))
				continue;

			// The Toolbox leaves the directories of old versions behind after an update, so we
			// check which build it actually considers the current one for this installation.
			historyJsonPath.Clear();

			if (GetHistoryJsonPath(riderPath, historyJsonPath) case .Ok)
			{
				RiderVersion lastBuildVersion = GetLastBuildVersion(historyJsonPath);

				if (lastBuildVersion.IsInitialized && installInfo.Version != lastBuildVersion)
				{
					delete installInfo;
					continue;
				}
			}

			outInstalls.Add(installInfo);
		}
	}

	/// Recursively searches the given directory for files with the given name.
	/// @remarks corlib's Directory.EnumerateFiles doesn't search subdirectories.
	protected static void FindFilesRecursive(StringView directory, StringView fileName, List<String> outPaths,
		int remainingDepth, ref int searchedDirectories)
	{
		if (remainingDepth <= 0 || searchedDirectories >= MaxSearchedDirectories)
			return;

		searchedDirectories++;

		for (FileFindEntry entry in Directory.EnumerateFiles(directory, fileName))
		{
			String path = new String();
			entry.GetFilePath(path);
			outPaths.Add(path);
		}

		// Reused across the iterations: a "scope" allocation inside a loop body lives until the
		// enclosing method returns, so allocating per iteration would grow the stack unboundedly.
		String entryName = scope .();
		String subDirectory = scope .();

		for (FileFindEntry entry in Directory.EnumerateDirectories(directory))
		{
			entryName.Clear();
			entry.GetFileName(entryName);

			if (entryName == "." || entryName == "..")
				continue;

			subDirectory.Clear();
			entry.GetFilePath(subDirectory);

			FindFilesRecursive(subDirectory, fileName, outPaths, remainingDepth - 1, ref searchedDirectories);
		}
	}

	/// Reads the custom install location out of the Toolbox' ".settings.json".
	protected static void ExtractPathFromSettingsJson(StringView toolboxPath, String outInstallLocation)
	{
		String settingsJsonPath = scope .();
		Path.Combine(settingsJsonPath, toolboxPath, ".settings.json");

		if (!File.Exists(settingsJsonPath))
			return;

		StructuredData data = scope .();
		if (data.Load(settingsJsonPath) case .Err)
			return;

		data.GetString("install_location", outInstallLocation);
	}

	/// Reads the version of a Rider installation out of its "product-info.json".
	protected static RiderVersion ParseProductInfoJson(StringView productInfoJsonPath, String outName, String outVersion)
	{
		StructuredData data = scope .();
		if (data.Load(productInfoJsonPath) case .Err)
			return .();

		String buildNumber = scope .();
		data.GetString("buildNumber", buildNumber);
		
		data.GetString("name", outName);
		data.GetString("version", outVersion);

		return RiderVersion.Parse(buildNumber);
	}

	/// Walks up from the given Rider executable looking for the Toolbox' ".history.json".
	protected static Result<void> GetHistoryJsonPath(StringView riderPath, String outPath)
	{
		String directory = scope .();
		Try!(Path.GetDirectoryPath(riderPath, directory));

		String parentDirectory = scope .();
		String historyPath = scope .();

		// Bounded so that we don't walk all the way up to the drive root.
		for (int i < 10)
		{
			if (!Directory.Exists(directory))
				break;

			historyPath.Clear();
			Path.Combine(historyPath, directory, ".history.json");

			if (File.Exists(historyPath))
			{
				outPath.Append(historyPath);
				return .Ok;
			}

			parentDirectory.Clear();
			if (Path.GetDirectoryPath(directory, parentDirectory) case .Err)
				break;

			if (parentDirectory.IsEmpty || parentDirectory == directory)
				break;

			directory.Set(parentDirectory);
		}

		return .Err;
	}

	/// Reads the build number of the most recent entry of the Toolbox' ".history.json".
	protected static RiderVersion GetLastBuildVersion(StringView historyJsonPath)
	{
		StructuredData data = scope .();
		if (data.Load(historyJsonPath) case .Err)
			return .();

		String lastBuild = scope .();

		// The most recent build is the last entry of the "history" array.
		for (data.Enumerate("history"))
		{
			lastBuild.Clear();

			using (data.Open("item"))
			{
				data.GetString("build", lastBuild);
			}
		}

		return RiderVersion.Parse(lastBuild);
	}
}
