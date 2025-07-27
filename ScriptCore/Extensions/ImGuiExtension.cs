using System;
using System.Runtime.CompilerServices;
using GlitchyEngine.Core;
using GlitchyEngine.Math;
using ImGuiNET;

namespace GlitchyEngine.Extensions;

public static class ImGuiDataTypeExtension
{
    public static ImGuiDataType GetImGuiDataType(Type type)
    {
        if (type == typeof(byte))
            return ImGuiDataType.U8;
        if (type == typeof(ushort))
            return ImGuiDataType.U16;
        if (type == typeof(uint))
            return ImGuiDataType.U32;
        if (type == typeof(ulong))
            return ImGuiDataType.U64;

        if (type == typeof(sbyte))
            return ImGuiDataType.S8;
        if (type == typeof(short))
            return ImGuiDataType.S16;
        if (type == typeof(int))
            return ImGuiDataType.S32;
        if (type == typeof(long))
            return ImGuiDataType.S64;

        if (type == typeof(float))
            return ImGuiDataType.Float;
        if (type == typeof(double))
            return ImGuiDataType.Double;

        throw new ArgumentException("The type must be an integer or float type.", nameof(type));
    }
}

public static class ImGuiExtension
{
    /// <summary>
    /// A helper function to attach a tooltip to the previous item. It automatically checks IsItemHovered before showing a tooltip with the given text.
    /// </summary>
    /// <param name="tooltip">The text to be displayed in the tooltip.</param>
    public static void AttachTooltip(string tooltip)
    {
        if (!ImGui.IsItemHovered())
            return;

        ImGui.BeginTooltip();
        
        ImGui.TextUnformatted(tooltip);
        
        ImGui.EndTooltip();
    }
    /// <summary>
    /// A helper function to attach a tooltip to the previous item. It automatically checks IsItemHovered before showing a tooltip with the given content.
    /// </summary>
    /// <param name="tooltipContent">A method that will be called to show the content of the tooltip.</param>
    public static void AttachTooltip(Action tooltipContent)
    {
        if (!ImGui.IsItemHovered())
            return;

        ImGui.BeginTooltip();

        tooltipContent();
        
        ImGui.EndTooltip();
    }

    public static void ListElementGrabber()
    {
        ScriptGlue.ImGuiExtension_ListElementGrabber();
    }

    public static bool ShowAssetDropTarget(ref UUID uuid)
    {
       return ScriptGlue.ImGuiExtension_ShowAssetDropTarget(ref uuid);
    }

    public static bool Checkbox2(string label, ref bool2 value) => CheckboxN(2, label, ref value.X);
    public static bool Checkbox3(string label, ref bool3 value) => CheckboxN(3, label, ref value.X);
    public static bool Checkbox4(string label, ref bool4 value) => CheckboxN(4, label, ref value.X);

    public static bool CheckboxN(int componentCount, string label, ref bool value)
    {
        bool changed = false;

        for (int i = 0; i < componentCount; i++)
        {
            if (i != 0)
                ImGui.SameLine();

            changed |= ImGui.Checkbox($"##{label}{i}", ref Unsafe.Add(ref value, i));
            
        }
        return changed;
    }

    public static unsafe bool DragUInt2(string label, ref uint2 value)
    {
        return ImGui.DragScalarN(label, ImGuiDataType.U32, (IntPtr)Unsafe.AsPointer(ref value), 2);
    }
    
    public static unsafe bool DragUInt3(string label, ref uint3 value)
    {
        return ImGui.DragScalarN(label, ImGuiDataType.U32, (IntPtr)Unsafe.AsPointer(ref value), 3);
    }
    
    public static unsafe bool DragUInt4(string label, ref uint4 value)
    {
        return ImGui.DragScalarN(label, ImGuiDataType.U32, (IntPtr)Unsafe.AsPointer(ref value), 4);
    }
    
    public static unsafe bool DragDouble2(string label, ref double2 value)
    {
        return ImGui.DragScalarN(label, ImGuiDataType.Double, (IntPtr)Unsafe.AsPointer(ref value), 2);
    }
    
    public static unsafe bool DragDouble3(string label, ref double3 value)
    {
        return ImGui.DragScalarN(label, ImGuiDataType.Double, (IntPtr)Unsafe.AsPointer(ref value), 3);
    }
    
    public static unsafe bool DragDouble4(string label, ref double4 value)
    {
        return ImGui.DragScalarN(label, ImGuiDataType.Double, (IntPtr)Unsafe.AsPointer(ref value), 4);
    }
}
