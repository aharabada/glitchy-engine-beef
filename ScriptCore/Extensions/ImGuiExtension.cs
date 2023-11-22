using System;
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
}
