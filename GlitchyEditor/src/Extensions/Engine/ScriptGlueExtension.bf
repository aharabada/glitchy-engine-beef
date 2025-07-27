using System;
using GlitchyEditor.EditWindows;
using GlitchyEngine.Content;

namespace GlitchyEngine.Scripting;

extension ScriptGlue
{
	static this()
	{
		OnRegisterNativeCalls.Add(new => RegisterExtensionCalls);
	}

	private static void RegisterExtensionCalls()
	{
		EngineFunctions.[Friend]_functions.ImGuiExtension_ShowAssetDropTarget = => ImGuiExtension_ShowAssetDropTarget;
	}

	[RegisterCall(EngineResultAsBool = true, IsExtension = true)]
	public static EngineResult ImGuiExtension_ShowAssetDropTarget(ref AssetHandle assetHandle)
	{
		return ComponentEditWindow.ShowAssetDropTarget(ref assetHandle) ? .Ok : .False;
	}
}
