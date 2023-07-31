using Bon;
using System;
using System.Collections;

namespace GlitchyEditor;

/// The user settings of this project
[BonTarget]
class ProjectUserSettings
{
	public static StringView FileName = "project_user.bon";

	/*[BonInclude]
	private String _lastOpenedScene ~ delete _;*/
	
	[BonInclude]
	private List<String> _recentScenes ~ DeleteContainerAndItems!(_);

	[BonIgnore]
	private bool _settingsDirty;

	/// Gets or sets the path of the Scene that was last open. (Relative to the workspace)
	public StringView LastOpenedScene
	{
		get
		{
			if (_recentScenes == null || _recentScenes.Count == 0)
				return "";

			return _recentScenes[0];
		}
		set
		{
			if (_recentScenes == null)
				_recentScenes = new List<String>();

			// Remove duplicates
			for (var entry in _recentScenes)
			{
				if (entry == value)
				{
					delete entry;
					@entry.Remove();
				}
			}

			_recentScenes.Insert(0, new String(value));

			if (_recentScenes.Count > 10)
			{
				// We only store 10 entries, delete the rest
				for (int i = 10; i < _recentScenes.Count; i++)
				{
					delete _recentScenes[i];
				}

				_recentScenes.Count = 10;
			}
		}
	}

	/// The scenes that were recently used.
	public List<String> RecentScenes => _recentScenes;

	public bool SettignsDirty
	{
		get => _settingsDirty;
		set => _settingsDirty = value;
	}

	public void RestoreDefaults()
	{
		//_lastOpenedScene?.Clear();
		if (_recentScenes != null)
			ClearAndDeleteItems!(_recentScenes);

		_settingsDirty = true;
	}
}
