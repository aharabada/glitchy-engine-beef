using GlitchyEngine.Math;
using ImGuizmo;
using System;

namespace GlitchyEditor;

static class Handles
{
	private static float3? _snap;

	public static Matrix View {get; private set;}
	public static Matrix Projection {get; private set;}

	private static bool _usedGizmo;

	public static bool UsedGizmo => _usedGizmo;

	public static void SetViewProjection(Matrix view, Matrix projection)
	{
		View = view;
		Projection = projection;
	}

	public static void SetSnap(float3? snap)
	{
		_snap = snap;
	}

	public static bool ShowGizmo(ref Matrix transform, ImGuizmo.OPERATION gizmoType, bool globalGizmo = true, int32? id = null)
	{
		if (id != null)
			ImGuizmo.SetID(id.Value);
#unwarn
		bool result = ImGuizmo.Manipulate((.)&View, (.)&Projection, gizmoType, globalGizmo ? .WORLD : .LOCAL, (.)&transform, null, _snap.HasValue ? (.)&_snap : null);

		_usedGizmo = ImGuizmo.IsUsing();

		return result;
	}
}
