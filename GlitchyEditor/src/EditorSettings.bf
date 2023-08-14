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

	//
	//public readonly List<String> RecentProjects = new .() ~ delete _;

	public void Apply()
	{
	}
}