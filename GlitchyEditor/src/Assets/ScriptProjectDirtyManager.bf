using System;
using System.IO;
using System.Collections;
using Oregano;
using System.Diagnostics;
using GlitchyEditor.Settings;

namespace GlitchyEditor.Assets;

class ScriptProjectDirtyManager
{
	private bool _anyAssetDirty;
	private bool _projectFileDirty;
	private bool _forceRebuild;

	public void AssetChanged(StringView assetPath)
	{
		_anyAssetDirty = true;

		_projectFileDirty |= CheckIfProjectFile(assetPath);
	}

	private bool CheckIfProjectFile(StringView assetPath)
	{
		for (Regex regex in _patterns)
		{
			if (regex.IsMatch(assetPath))
			{
				return true;
			}
		}

		return false;
	}
	
	public void SetClean()
	{
		_anyAssetDirty = false;
		_projectFileDirty = false;
		_forceRebuild = false;
	}

	public void SetVeryDirty()
	{
		_forceRebuild = true;
	}

	public bool NeedsRebuild(RebuildOnPlay rebuildMode)
	{
		switch (rebuildMode)
		{
		case .Off:
			return _forceRebuild;
		case .Always:
			return true;
		case .WhenAnyAssetsChanged:
			return _anyAssetDirty || _forceRebuild;
		case .UseFastUpToDateCheck:
			return _projectFileDirty || _forceRebuild;
		}
	}

	private static List<StringView> patterns = new .(){
		"**/*.cs", // C# source files
		"**/*.csproj", // C# Project file
		"**/*.props", // MSBuild properties
		"**/*.targets", // MSBuild targets
		"**/*.resx", // Embedded .NET-Ressources
		"**/*.editorconfig", // Compiler- and Analyzer-config
		"**/*.globalconfig", // Global Analyzer-config
		"**/global.json",
		"**/NuGet.Config",
		"**/packages.lock.json",
		"**/runtimeconfig.template.json"
	} ~ delete _;

	private List<Regex> _patterns = new .() ~ DeleteContainerAndItems!(_);
	// Oregano's Regex doesn't copy the pattern but keeps StringViews into it, so the strings must live as long as the regexes.
	private List<String> _patternStrings = new .() ~ DeleteContainerAndItems!(_);

	public this()
	{
		for (StringView pattern in patterns)
		{
			String regexString = new .();

			if (CompileRegexFromGlob(pattern, regexString) case .Ok(let regex))
			{
				_patternStrings.Add(regexString);
				_patterns.Add(regex);
			}
			else
			{
				delete regexString;
			}
		}
	}

	/// Converts the glob into a regex string (written to outRegex) and compiles it.
	/// The returned Regex references outRegex, so outRegex must outlive it.
	private static Result<Regex> CompileRegexFromGlob(StringView glob, String outRegex)
	{
		outRegex.Append('^');

		int inBrackets = 0;
		bool isInBrackets() => inBrackets > 0;

		bool isWildcard = false;
		bool wasDoubleWildcard = false;

		for (char8 c in glob)
		{
			if (isWildcard)
			{
				isWildcard = false;
				if (c == '*')
				{
					// **
					outRegex.Append(@"(?:.*[\\/])?");
					wasDoubleWildcard = true;
					continue;
				}
				else
				{
					outRegex.Append(@"[^\\/]*");
				}
			}

			if (c == '[')
			{
				inBrackets++;
				outRegex.Append(c);
				continue;
			}
			else if (c == ']')
			{
				inBrackets--;
				outRegex.Append(c);
				continue;
			}

			if (c == '.')
			{
				if (isInBrackets())
					outRegex.Append('.');
				else
					outRegex.Append(@"\.");

				continue;
			}

			if (isInBrackets())
			{
				outRegex.Append(c);
				continue;
			}
			else
			{
				if (c == '?')
				{
					outRegex.Append(@"[^\\/]");
					continue;
				}
				else if (c == '*')
				{
					isWildcard = true;
					continue;
				}
				else if (c == '/')
				{
					if (!wasDoubleWildcard)
						outRegex.Append(@"\/");
					continue;
				}
				else
				{
					outRegex.Append(c);
					continue;
				}
			}
		}

		outRegex.Append('$');

		return Regex.Compile(outRegex);
	}
}
