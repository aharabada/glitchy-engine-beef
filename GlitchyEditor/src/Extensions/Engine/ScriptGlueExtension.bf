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
	
	[RegisterMethod(IsExtension = true)]
	private static void RegisterExtensionCalls()
	{
	}

	[RegisterCall(EngineResultAsBool = true, IsExtension = true)]
	static EngineResult ImGuiExtension_ShowAssetDropTarget(ref AssetHandle assetHandle)
	{
		return ComponentEditWindow.ShowAssetDropTarget(ref assetHandle) ? .Ok : .False;
	}
	
	[RegisterCall(IsExtension = true), CallingConvention(.Cdecl)]
	static void ImGuiExtension_ListElementGrabber()
	{
		ImGui.ImGui.ListElementGrabber();
	}
}
