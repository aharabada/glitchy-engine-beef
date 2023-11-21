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

//namespace ImGuiNET;

//public static unsafe partial class ImGui
//{
//    [DllImport("__Internal", CallingConvention = CallingConvention.Cdecl)]
//    private static extern unsafe bool ImGui_EditFloat2(byte* label, ref float2 value, float2 resetValues, float dragSpeed, float columnWidth, float2 minValue, float2 maxValue, bool2 componentEnabled);

//    public static bool EditFloat2(string label, ref float2 value, float2 resetValues = default, float dragSpeed = 0.1f,
//        float columnWidth = 100f, float2 minValue = default, float2 maxValue = default)
//    {
//        byte* native_label;
//        int label_byteCount = 0;
//        if (label != null)
//        {
//            label_byteCount = Encoding.UTF8.GetByteCount(label);
//            if (label_byteCount > Util.StackAllocationSizeLimit)
//            {
//                native_label = Util.Allocate(label_byteCount + 1);
//            }
//            else
//            {
//                byte* native_label_stackBytes = stackalloc byte[label_byteCount + 1];
//                native_label = native_label_stackBytes;
//            }
//            int native_label_offset = Util.GetUtf8(label, native_label, label_byteCount);
//            native_label[native_label_offset] = 0;
//        }
//        else { native_label = null; }

//        return ImGui_EditFloat2(native_label, ref value, resetValues, dragSpeed, columnWidth, minValue, maxValue, true);
//    }

//    public static bool EditFloat2(string label, ref float2 value, float2 resetValues, float dragSpeed,
//        float columnWidth, float2 minValue, float2 maxValue, bool2 componentEnabled)
//    {
//        return ImGui_EditFloat2(label, ref value, resetValues, dragSpeed, columnWidth, minValue, maxValue, true);
//    }

//    //ImGui_EditFloat2(char8* label, ref float2 value, float2 resetValues = .Zero, float dragSpeed = 0.1f, float columnWidth = 100f, float2 minValue = .Zero, float2 maxValue = .Zero, bool2 componentEnabled = true)
//}
