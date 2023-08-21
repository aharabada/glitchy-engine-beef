using System;
using GlitchyEngine;
using Bon;
using GlitchyEditor;
using System.Collections;

namespace GlitchyEngine
{
	extension Settings
	{
		[SettingContainer, BonInclude]
		public readonly EditorSettings EditorSettings = new .() ~ delete _;

		public this()
		{
			OnApplySettings.Add(new (s, e) => EditorSettings.Apply());
		}
	}
}

namespace GlitchyEditor;

[Reflect]
class EditorSettings
{
	[Setting("Editor", "Switch to Player on play", "If checked the editor will automatically switch to the \"Play\" window after starting the game."), BonInclude]
	public bool SwitchToPlayerOnPlay = true;

	[Setting("Editor", "Switch to Player on simulate", "If checked the editor will automatically switch to the \"Play\" window after starting the simulation."), BonInclude]
	public bool SwitchToPlayerOnSimulate = true;
	
	[Setting("Editor", "Switch to Player on continue", "If checked the editor will automatically switch to the \"Play\" window when the game is continued after pausing."), BonInclude]
	public bool SwitchToPlayerOnResume = false;

	[Setting("Editor", "Switch to Editor on stop", "If checked the editor will automatically switch to the \"Editor\" window after stopping the game."), BonInclude]
	public bool SwitchToEditorOnStop = true;
	
	[Setting("Editor", "Switch to Editor on pause", "If checked the editor will automatically switch to the \"Editor\" window when the game is being paused."), BonInclude]
	public bool SwitchToEditorOnPause = false;
	
	[BonInclude]
	private List<String> _recentProjects ~ DeleteContainerAndItems!(_);

	/// Gets or sets the path of the Project that was last open.
	public StringView LastOpenedProject
	{
		get
		{
			if (_recentProjects == null || _recentProjects.Count == 0)
				return "";

			return _recentProjects[0];
		}
		set
		{
			if (_recentProjects == null)
				_recentProjects = new List<String>();

			// Remove duplicates
			for (var entry in _recentProjects)
			{
				if (entry == value)
				{
					delete entry;
					@entry.Remove();
				}
			}

			_recentProjects.Insert(0, new String(value));

			if (_recentProjects.Count > 10)
			{
				// We only store 10 entries, delete the rest
				for (int i = 10; i < _recentProjects.Count; i++)
				{
					delete _recentProjects[i];
				}

				_recentProjects.Count = 10;
			}
		}
	}

	public List<String> RecentProjects => _recentProjects;

	public void Apply()
	{
	}
}