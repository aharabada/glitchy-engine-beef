using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Globalization;
using System.Linq;
using System.Numerics;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Text;
using GlitchyEngine.Core;
using GlitchyEngine.Extensions;
using GlitchyEngine.Math;
using GlitchyEngine.Math.Attributes;
using ImGuiNET;
using Component = GlitchyEngine.Core.Component;

namespace GlitchyEngine.Editor;

class DidNotChange
{
}

internal class EntityEditor
{
    public static readonly DidNotChange DidNotChange = new DidNotChange();
    
    private delegate object? ShowCustomEditorMethod(object? reference, Type fieldType, string fieldName);

    private static Dictionary<Type, ShowCustomEditorMethod> _customEditors = new();

    static EntityEditor()
    {
        foreach (Type type in TypeExtension.EnumerateAllTypes())
        {
            if (type.TryGetCustomAttribute<CustomEditorAttribute>(out var attribute))
            {
                MethodInfo? showEditorMethod = type.GetMethod("ShowEditor", BindingFlags.Static | BindingFlags.Public,
                    null,
                    new []{ typeof(object), typeof(Type), typeof(string) }, null);

                if (showEditorMethod == null)
                {
                    Log.Error($"No ShowEditor-method found for type {type}");
                }
                else
                {
                    ShowCustomEditorMethod method = showEditorMethod.GetDelegate<ShowCustomEditorMethod>();

                    _customEditors.Add(attribute.Type, method);
                }
            }
        }
    }
    
    public static void BeginNewRow()
    {
        if (!StartNewProperty_NewRow)
        {
            StartNewProperty_NewRow = true;
            return;
        }

        ImGui.TableNextRow();
        ImGui.TableSetColumnIndex(0);
    }

    public static bool StartNewProperty_NewRow = true;

    /// <summary>
    /// Starts a new property by creating a new table row, writing the name in the first column and entering the second column.
    /// </summary>
    /// <param name="propertyName">The label that will be show in the label column.</param>
    /// <param name="attributes">The list of attributes of the field. If it contains a <see cref="TooltipAttribute"/>, this will be used as the tooltip.
    /// If null or the attribute isn't in the list, <see cref="propertyName"/> will be used as tooltip.</param>
    /// <returns>A string containing the propertyName as ImGui id</returns>
    private static string StartNewProperty(string propertyName, IEnumerable<Attribute>? attributes)
    {
        TooltipAttribute? tooltip = GetAttribute<TooltipAttribute>(attributes);

        return StartNewProperty(propertyName, tooltip?.Tooltip);
    }
    
    /// <summary>
    /// Starts a new property by creating a new table row, writing the name in the first column and entering the second column.
    /// </summary>
    /// <param name="propertyName">The label that will be show in the label column.</param>
    /// <param name="tooltip">The tooltip that will be shown when hovering over the label. If null, <see cref="propertyName"/> will be used as tooltip.</param>
    /// <returns>A string containing the propertyName as ImGui id</returns>
    private static string StartNewProperty(string propertyName, string? tooltip = null)
    {
        ImGui.TextUnformatted(propertyName);
        
        ImGuiExtension.AttachTooltip(tooltip ?? propertyName);

        ImGui.TableSetColumnIndex(1);

        return $"##{propertyName}";
    }

    private static bool TryShowCustomEditor(object? reference, Type fieldType, string fieldName, out object? editedValue)
    {
        editedValue = DidNotChange;

        try
        {
            // Try to match the concrete type first (e.g. Foo -> Foo and Foo<Bar> -> List<Bar>)
            // Note: Foo<Bar> wont match a serializer for Foo<>
            if (_customEditors.TryGetValue(fieldType, out ShowCustomEditorMethod customEditorMethod))
            {
                editedValue = customEditorMethod(reference, fieldType, fieldName);
                return true;
            }
            
            if (fieldType.IsGenericType && _customEditors.TryGetValue(fieldType.GetGenericTypeDefinition(), out customEditorMethod))
            {
                editedValue = customEditorMethod(reference, fieldType, fieldName);
                return true;
            }
        }
        catch (Exception e)
        {
            Log.Exception(e);
        }

        return false;
    }

    public static bool ShowFieldInEditor(FieldInfo fieldInfo)
    {
        if (fieldInfo.IsPublic)
        {
            // Public fields are visible by default (No HideInEditorAttribute)
            if (fieldInfo.HasCustomAttribute<HideInEditorAttribute>())
                return false;

            return true;
        }
        
        // Private, protected and internal fields are hidden by default (No ShowInEditorAttribute)
        if (fieldInfo.HasCustomAttribute<ShowInEditorAttribute>())
            return true;

        return false;
    }
    
    /// <summary>
    /// Entry point for the engine to show the editor for the given script instance.
    /// </summary>
    /// <param name="scriptInstance">The script instance to show the editor for.</param>
    internal static void ShowEntityEditor(Entity? scriptInstance)
    {
        if (scriptInstance == null)
            return;

        // TODO: Call custom editors here!
        ShowEditor(scriptInstance.GetType(), scriptInstance);
    }

    private static T? GetAttribute<T>(IEnumerable<Attribute>? attributes) where T : Attribute
    {
        return (T?)attributes?.FirstOrDefault(a => a is T);
    }

    private static object ShowDecimalEditor(object? reference, Type fieldType, string fieldName, IEnumerable<Attribute>? attributes)
    {
        if (reference is not decimal value)
            return DidNotChange;

        string stringValue = value.ToString(CultureInfo.InvariantCulture);

        byte[] bytes = new byte[30 * 4];

        Encoding.UTF8.GetBytes(stringValue, 0, stringValue.Length, bytes, 0);

        ImGui.PushID("Decimal");
        
        string fieldId = StartNewProperty(fieldName, attributes);

        if (ImGui.InputText(fieldId, bytes, (uint)bytes.Length, ImGuiInputTextFlags.EnterReturnsTrue | ImGuiInputTextFlags.CharsDecimal))
        {
            string text = Encoding.UTF8.GetString(bytes);

            if (decimal.TryParse(text, NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out decimal newValue))
            {
                ImGui.PopID();
                return newValue;
            }
        }
        ImGui.PopID();

        return DidNotChange;
    }

    private static object ShowPrimitiveEditor(object reference, Type fieldType, string fieldName, IEnumerable<Attribute>? attributes)
    {
        Debug.Assert(reference != null);

        string fieldId = StartNewProperty(fieldName, attributes);

        object newValue = DidNotChange;

        unsafe void DragScalar<T>(ImGuiDataType dataType) where T : unmanaged
        {
            T ChangeTypeSafe(object value)
            {
                try
                {
                    return (T)Convert.ChangeType(value, typeof(T));
                }
                catch (OverflowException e)
                {
                    // Log.Error($"Could not apply value: {e.Message}");
                    ImGui.TextColored(new Vector4(1, 0, 0, 1), $"Value {value} can not be converted to type {typeof(T)}: {e.Message}.");

                    return default;
                }
            }

            NumberFormatAttribute? numberFormat = GetAttribute<NumberFormatAttribute>(attributes);
            
            string? format = numberFormat?.Format;
            
            RangeAttribute? range = GetAttribute<RangeAttribute>(attributes);

            // Get Min and Max Values from Type T
            T min = ReadStaticField<T>("MinValue");
            T max = ReadStaticField<T>("MaxValue");
            float dragSpeed = 1.0f;
            
            // RangeAttribute takes precedence over Minimum- and Maximum-Attribute
            if (range != null)
            {
                min = ChangeTypeSafe(range.Min);
                max = ChangeTypeSafe(range.Max);
                dragSpeed = range.Speed;
            }
            else
            {
                MinimumAttribute? minimum = GetAttribute<MinimumAttribute>(attributes);
                MaximumAttribute? maximum = GetAttribute<MaximumAttribute>(attributes);
                
                // Don't use range, if it is invalid
                if (minimum != null && maximum != null && minimum.Min > maximum.Max)
                {
                    //Log.Error($"Minimum value ({minimum.Min}) specified for field {fieldName} must not be greater than the maximum value ({maximum.Max})! Ignoring range...");
                    ImGui.TextColored(new Vector4(1, 0, 0, 1), $"Minimum value ({minimum.Min}) specified for field {fieldName} must not be greater than the maximum value ({maximum.Max})! Ignoring range...");
                }
                else
                {
                    if (minimum != null)
                        min = ChangeTypeSafe(minimum.Min);

                    if (maximum != null)
                        max = ChangeTypeSafe(maximum.Max);
                }
            }

            var value = (T)reference!;

            if (range?.Slider == true)
            {
                if (ImGui.SliderScalar(fieldId, dataType, (IntPtr)(&value), (IntPtr)(&min), (IntPtr)(&max), format))
                {
                    newValue = value;
                }
            }
            else
            {
                if (ImGui.DragScalar(fieldId, dataType, (IntPtr)(&value), dragSpeed, (IntPtr)(&min), (IntPtr)(&max), format))
                {
                    newValue = value;
                }
            }
        }

        if (fieldType == typeof(bool))
        {
            bool value = (bool)reference!;
            if (ImGui.Checkbox(fieldId, ref value))
                newValue = value;
        }
        else if (fieldType == typeof(char))
        {
            unsafe
            {
                // TODO: Allow escaped unicode chars \u XXXX
                // TODO: Add text input validation, so that it isn't possible to type invalid chars

                char* value = stackalloc char[4];
                switch((char)reference!)
                {
                    case '\a':
                        value[0] = '\\';
                        value[1] = 'a';
                        break;
                    case '\b':
                        value[0] = '\\';
                        value[1] = 'b';
                        break;
                    case '\f':
                        value[0] = '\\';
                        value[1] = 'f';
                        break;
                    case '\n':
                        value[0] = '\\';
                        value[1] = 'n';
                        break;
                    case '\r':
                        value[0] = '\\';
                        value[1] = 'r';
                        break;
                    case '\t':
                        value[0] = '\\';
                        value[1] = 't';
                        break;
                    case '\v':
                        value[0] = '\\';
                        value[1] = 'v';
                        break;
                    default:
                        value[0] = (char)reference;
                        value[1] = '\0';
                        break;
                };

                // Enough space to store two code points
                byte* buffer = stackalloc byte[8];
                int encodedBytes = Encoding.UTF8.GetBytes(value, 2, buffer, 8);

                // Place string delimiter after encoded UTF8 sequence.
                buffer[encodedBytes] = (byte)'\0';

                if (ImGui.InputText(fieldId, (IntPtr)buffer, 8))
                {
                    if (buffer[0] == '\\' && buffer[1] != '\0')
                    {
                        newValue = (char)buffer[1] switch
                        {
                            'a' => newValue = '\a',
                            'b' => newValue = '\b',
                            'f' => newValue = '\f',
                            'n' => newValue = '\n',
                            'r' => newValue = '\r',
                            't' => newValue = '\t',
                            'v' => newValue = '\v',
                            _ => newValue = '\\'
                        };
                    }
                    else
                    {
                        // Only decode first codepoint
                        Encoding.UTF8.GetChars(buffer, 4, value, 4);

                        newValue = value[0];
                    }
                }   
            }
        }
        else if (fieldType == typeof(byte))
            DragScalar<byte>(ImGuiDataType.U8);
        else if (fieldType == typeof(sbyte))
            DragScalar<sbyte>(ImGuiDataType.S8);
        else if (fieldType == typeof(short))
            DragScalar<short>(ImGuiDataType.S16);
        else if (fieldType == typeof(ushort))
            DragScalar<ushort>(ImGuiDataType.U16);
        else if (fieldType == typeof(int))
            DragScalar<int>(ImGuiDataType.S32);
        else if (fieldType == typeof(uint))
            DragScalar<uint>(ImGuiDataType.U32);
        else if (fieldType == typeof(long))
            DragScalar<long>(ImGuiDataType.S64);
        else if (fieldType == typeof(ulong))
            DragScalar<ulong>(ImGuiDataType.U64);
        else if (fieldType == typeof(float))
            DragScalar<float>(ImGuiDataType.Float);
        else if (fieldType == typeof(double))
            DragScalar<double>(ImGuiDataType.Double);
        else
        {
            ImGui.TextColored(new Vector4(1, 0, 0, 1), $"{fieldName}: Type {fieldType} is not implemented.");
        }
        
        return newValue;
    }

    private static object ShowEnumEditor(object? reference, Type fieldType, string fieldName, IEnumerable<Attribute>? attributes)
    {
        string fieldId = StartNewProperty(fieldName, attributes);

        object newValue = DidNotChange;
        if (ImGui.BeginCombo(fieldId, reference?.ToString()))
        {
            foreach (object enumValue in Enum.GetValues(fieldType))
            {
                string enumValueName = enumValue.ToString();

                FieldInfo? fieldInfo = fieldType.GetField(enumValueName);

                string enumValueLabel;

                if (fieldInfo != null)
                {
                    LabelAttribute label = (LabelAttribute)Attribute.GetCustomAttribute(fieldInfo, typeof(LabelAttribute));

                    if (label != null)
                    {
                        enumValueLabel = label.Label ?? enumValueName;
                    }
                    else
                    {
                        enumValueLabel = enumValueName.ToPrettyName();
                    }
                }
                else
                {
                    enumValueLabel = enumValueName.ToPrettyName();
                }

                if (ImGui.Selectable(enumValueLabel, enumValue == reference))
                {
                    newValue = enumValue;
                }
            }

            ImGui.EndCombo();
        }

        return newValue;
    }

    public static object? ShowFieldEditor(object? reference, Type fieldType, string fieldName, IEnumerable<Attribute>? attributes = null)
    {
        ReadonlyAttribute? readonlyAttribute = GetAttribute<ReadonlyAttribute>(attributes);
        
        ImGui.BeginDisabled(readonlyAttribute != null);

        object? newValue = DidNotChange;
        
        BeginNewRow();

        if (TryShowCustomEditor(reference, fieldType, fieldName, out newValue))
        {

        }
        else if (fieldType.IsGenericType)
        {
            if (fieldType.GetGenericTypeDefinition() == typeof(List<>))
            {
                newValue = ShowListEditor(fieldType, reference, fieldName);
            }
            else
            {
                ImGui.TextColored(new Vector4(1, 0, 0, 1), $"{fieldName}: Type {fieldType} is not implemented.");
            }
        }
        else if (fieldType.IsArray)
        {
            newValue = ShowArrayEditor(fieldType, reference, fieldName);
        }
        else if (fieldType.IsEnum)
        {
            newValue = ShowEnumEditor(reference, fieldType, fieldName, attributes);
        }
        else if (fieldType.IsPrimitive)
        {
            newValue = ShowPrimitiveEditor(reference!, fieldType, fieldName, attributes);
        }
        else if (fieldType.IsValueType)
        {
            if (fieldType == typeof(decimal))
            {
                newValue = ShowDecimalEditor(reference, fieldType, fieldName, attributes);
            }
            else if (fieldType == typeof(ColorRGBA))
            {
                string fieldId = StartNewProperty(fieldName, attributes);

                ColorRGBA value = (ColorRGBA)reference!;
                if (ImGui.ColorEdit4(fieldId, ref Unsafe.As<ColorRGBA, Vector4>(ref value)))
                    newValue = value;
            }
            else if (fieldType.TryGetCustomAttribute(out VectorAttribute vectorAttribute))
            {
                newValue = ShowVectorEditor(reference, fieldType, fieldName, vectorAttribute, attributes);
            }
            else
            {
                newValue = ShowObjectEditor(reference, fieldType, fieldName, attributes);
            }
        }
        else if (fieldType.IsSubclassOf(typeof(Entity)) || fieldType == typeof(Entity))
        {
            newValue = ShowEntityDropTarget(fieldName, fieldType, reference, attributes);
        }
        else if (fieldType.IsSubclassOf(typeof(Component)))
        {
            newValue = ShowComponentDropTarget(fieldName, fieldType, reference, attributes);
        }
        else if (fieldType == typeof(string))
        {
            newValue = ShowStringEditor(reference, fieldType, fieldName, attributes);
        }
        else
        {
            newValue = ShowObjectEditor(reference, fieldType, fieldName, attributes);
        }

        ImGui.EndDisabled();

        return newValue;
    }

    private static object ShowVectorEditor(object? reference, Type fieldType, string fieldName, VectorAttribute vectorAttribute, IEnumerable<Attribute>? attributes)
    {
        object newValue = DidNotChange;
        
        string fieldId = StartNewProperty(fieldName, attributes);

        if (vectorAttribute.Type == typeof(bool))
        {
            if (vectorAttribute.ComponentCount == 2)
            {
                bool2 value = (bool2)reference!;
                if (ImGuiExtension.Checkbox2(fieldId, ref value))
                    newValue = value;
            }
            else if (vectorAttribute.ComponentCount == 3)
            {
                bool3 value = (bool3)reference!;
                if (ImGuiExtension.Checkbox3(fieldId, ref value))
                    newValue = value;
            }
            else if (vectorAttribute.ComponentCount == 4)
            {
                bool4 value = (bool4)reference!;
                if (ImGuiExtension.Checkbox4(fieldId, ref value))
                    newValue = value;
            }
        }
        else if (vectorAttribute.Type == typeof(int))
        {
            if (vectorAttribute.ComponentCount == 2)
            {
                int2 value = (int2)reference!;
                if (ImGui.DragInt2(fieldId, ref value.X))
                    newValue = value;
            }
            else if (vectorAttribute.ComponentCount == 3)
            {
                int3 value = (int3)reference!;
                if (ImGui.DragInt3(fieldId, ref value.X))
                    newValue = value;
            }
            else if (vectorAttribute.ComponentCount == 4)
            {
                int4 value = (int4)reference!;
                if (ImGui.DragInt4(fieldId, ref value.X))
                    newValue = value;
            }
        }
        else if (vectorAttribute.Type == typeof(uint))
        {
            if (vectorAttribute.ComponentCount == 2)
            {
                uint2 value = (uint2)reference!;
                if (ImGuiExtension.DragUInt2(fieldId, ref value))
                    newValue = value;
            }
            else if (vectorAttribute.ComponentCount == 3)
            {
                uint3 value = (uint3)reference!;
                if (ImGuiExtension.DragUInt3(fieldId, ref value))
                    newValue = value;
            }
            else if (vectorAttribute.ComponentCount == 4)
            {
                uint4 value = (uint4)reference!;
                if (ImGuiExtension.DragUInt4(fieldId, ref value))
                    newValue = value;
            }
        }
        else if (vectorAttribute.Type == typeof(float))
        {
            if (vectorAttribute.ComponentCount == 2)
            {
                float2 value = (float2)reference!;
                if (ImGui.DragFloat2(fieldId, ref Unsafe.As<float2, Vector2>(ref value)))
                    newValue = value;
            }
            else if (vectorAttribute.ComponentCount == 3)
            {
                float3 value = (float3)reference!;
                if (ImGui.DragFloat3(fieldId, ref Unsafe.As<float3, Vector3>(ref value)))
                    newValue = value;
            }
            else if (vectorAttribute.ComponentCount == 4)
            {
                float4 value = (float4)reference!;
                if (ImGui.DragFloat4(fieldId, ref Unsafe.As<float4, Vector4>(ref value)))
                    newValue = value;
            }
        }
        else if (vectorAttribute.Type == typeof(double))
        {
            if (vectorAttribute.ComponentCount == 2)
            {
                double2 value = (double2)reference!;
                if (ImGuiExtension.DragDouble2(fieldId, ref value))
                    newValue = value;
            }
            else if (vectorAttribute.ComponentCount == 3)
            {
                double3 value = (double3)reference!;
                if (ImGuiExtension.DragDouble3(fieldId, ref value))
                    newValue = value;
            }
            else if (vectorAttribute.ComponentCount == 4)
            {
                double4 value = (double4)reference!;
                if (ImGuiExtension.DragDouble4(fieldId, ref value))
                    newValue = value;
            }
        }

        return newValue;
    }

    private static object? ShowObjectEditor(object? reference, Type fieldType, string fieldName, IEnumerable<Attribute>? attributes)
    {
        object? newValue = DidNotChange;
        
        //ReadonlyAttribute? readonlyAttribute = GetAttribute<ReadonlyAttribute>(attributes);
        
        // TODO: Disabling stuff
        //ImGui.EndDisabled();

        ImGui.BeginDisabled(reference == null);
        
        if (reference == null)
            ImGui.SetNextItemOpen(false);

        bool open = ImGui.TreeNodeEx(fieldName, ImGuiTreeNodeFlags.AllowOverlap | ImGuiTreeNodeFlags.SpanAllColumns);
        
        ImGui.EndDisabled();

        ImGui.TableSetColumnIndex(1);

        if (!fieldType.IsValueType)
        {
            if (reference == null)
            {
                Type? selectedType = ShowTypeDropdown("##Create", "Create instance...", fieldType);

                if (selectedType != null)
                {
                    newValue = ActivatorExtension.CreateInstanceSafe(selectedType);
                }
            }
            else
            {
                if (ImGui.SmallButton("Remove"))
                {
                    newValue = null;
                }
            }
        }
        else
        {
            newValue = reference;
        }
        
        if (open)
        {
            //ImGui.BeginDisabled(readonlyAttribute != null);

            Debug.Assert(reference != null);

            ShowEditor(reference!.GetType(), reference);

            ImGui.TreePop();
        }

        return newValue;
    }

    /// <summary>
    /// Shows a dropdown of all types that can be assigned to the given baseType.
    /// </summary>
    /// <param name="label">The label of the combo box.</param>
    /// <param name="previewValue">The preview value that will be shown in the combo box.</param>
    /// <param name="baseType">The base type of the types that can be selected.</param>
    /// <returns>The selected type; or <see langword="null"/> if no type was selected.</returns>
    private static Type? ShowTypeDropdown(string label, string? previewValue, Type baseType)
    {
        Type? selectedType = null;
        
        if (ImGui.BeginCombo(label, previewValue, ImGuiComboFlags.HeightSmall | ImGuiComboFlags.NoArrowButton))
        {
            foreach (Type t in TypeExtension.FindDerivedTypes(baseType))
            {
                if (t.IsGenericType)
                {
                    // TODO: Generic types
                }
                else
                {
                    if (ImGui.Selectable(t.Name))
                    {
                        selectedType = t;
                    }
                }
            }

            ImGui.EndCombo();
        }

        return selectedType;
    }

    private static object? ShowComponentDropTarget(string fieldName, Type fieldType, object? currentValue, IEnumerable<Attribute>? attributes)
    {
        object? newValue = DidNotChange;
        
        string fieldId = StartNewProperty(fieldName, attributes);

        Component? component = currentValue as Component;

        string entityName = "None";

        if (component != null)
        {
            entityName = component.Entity.Name;
        }
        
        Type? actualType = component?.GetType();

        entityName += $" ({(actualType ?? fieldType).Name})";
        
        if (ImGui.Button(entityName))
        {
            if (component?.Entity != null)
            {
                // TODO: Hightlight Entity in hierarchy
                // TODO: Highlight Component in editor
            }
        }

        if (ImGui.BeginDragDropTarget())
        {
            ImGuiPayloadPtr peekPayload = ImGui.AcceptDragDropPayload("ENTITY", ImGuiDragDropFlags.AcceptPeekOnly);

            bool allowDrop = false;
            
            unsafe
            {
                if (peekPayload.NativePtr != null)
                {
                    UUID draggedId = *(UUID*)peekPayload.Data;

                    Entity draggedEntity = new Entity(draggedId);

                    allowDrop = draggedEntity.HasComponent(fieldType);
                }

                if (allowDrop)
                {
                    ImGuiPayloadPtr payload = ImGui.AcceptDragDropPayload("ENTITY");
                    
                    if (payload.NativePtr != null)
                    {
                        UUID droppedId = *(UUID*)payload.Data;
                        
                        Entity draggedEntity = new Entity(droppedId);

                        try
                        {
                            newValue = draggedEntity.GetComponent(fieldType);
                        }
                        catch (Exception e)
                        {
                            Log.Exception(e);
                        }
                    }
                }
            }

            ImGui.EndDragDropTarget();
        }

        return newValue;
    }

    private static object? ShowEntityDropTarget(string fieldName, Type fieldType, object? currentValue, IEnumerable<Attribute>? attributes)
    {
        object? newValue = DidNotChange;
        
        string fieldId = StartNewProperty(fieldName, attributes);

        string entityName = "None";
        
        Entity? entity = currentValue as Entity;

        if (entity != null)
        {
            entityName = entity.Name;
        }

        Type? actualType = entity?.GetType();

        entityName += $" ({(actualType ?? fieldType).Name})";

        if (ImGui.Button(entityName))
        {
            if (entity != null)
            {
                // TODO: Hightlight Entity in hierarchy
            }
        }

        if (ImGui.BeginDragDropTarget())
        {
            ImGuiPayloadPtr peekPayload = ImGui.AcceptDragDropPayload("ENTITY", ImGuiDragDropFlags.AcceptPeekOnly);

            bool allowDrop = false;
            
            unsafe
            {
                if (peekPayload.NativePtr != null)
                {
                    UUID draggedId = *(UUID*)peekPayload.Data;

                    Entity draggedEntity = new Entity(draggedId);

                    // TODO: Check if entity is valid?

                    if (fieldType == typeof(Entity))
                    {
                        allowDrop = true;
                    }
                    else
                    {
                        Entity? scriptInstance = Entity.GetScriptReference(draggedId, typeof(Entity));

                        allowDrop = fieldType.IsInstanceOfType(scriptInstance);
                    }
                }

                if (allowDrop)
                {
                    ImGuiPayloadPtr payload = ImGui.AcceptDragDropPayload("ENTITY");
                    
                    if (payload.NativePtr != null)
                    {
                        UUID droppedId = *(UUID*)payload.Data;
                        
                        if (fieldType == typeof(Entity))
                        {
                            newValue = new Entity(droppedId);
                        }
                        else
                        {
                            newValue = Entity.GetScriptReference(droppedId, typeof(Entity));
                        }
                    }
                }
            }

            ImGui.EndDragDropTarget();
        }

        ImGui.SameLine();

        if (ImGui.Button("..."))
        {
            // TODO: Show entity selector
        }

        ImGuiExtension.AttachTooltip("Search entity...");

        return newValue;
    }

    private static object ShowStringEditor(object? reference, Type fieldType, string fieldName, IEnumerable<Attribute>? attributes)
    {
        string fieldId = StartNewProperty(fieldName, attributes);

        object newValue = DidNotChange;

        TextFieldAttribute? textField = GetAttribute<TextFieldAttribute>(attributes);

        string value = reference as string ?? "";

        if (textField?.Multiline == true)
        {
            if (ImGui.InputTextMultiline(fieldId, ref value, 1000, new Vector2(-1.0f, ImGui.GetTextLineHeight() * textField.TextFieldLines)))
                newValue = value;
        }
        else
        {
            if (ImGui.InputText(fieldId, ref value, 1000, ImGuiInputTextFlags.EnterReturnsTrue))
                newValue = value;
        }

        return newValue;
    }

    public static void ShowEditor(Type type, object? reference)
    {
        int i = 0;

        // Iterate all fields
        foreach (FieldInfo field in type.GetFields(BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public))
        {
            i++;
            ImGui.PushID(i);

            if (ShowFieldInEditor(field))
            {
                object value = field.GetValue(reference);

                IEnumerable<Attribute> attributes = field.GetCustomAttributes();

                LabelAttribute? label = GetAttribute<LabelAttribute>(attributes);

                string prettyName;

                if (label != null)
                {
                    prettyName = label.Label ?? field.Name;
                }
                else
                {
                    prettyName = field.Name.ToPrettyName();
                }

                object? newValue = ShowFieldEditor(value, value?.GetType() ?? field.FieldType, prettyName, attributes);

                if (newValue != DidNotChange)
                {
                    // Reference was changed inside Field Editor -> write back to field (only necessary for value types)
                    field.SetValue(reference, newValue);
                }
            }
            
            ImGui.PopID();
        }

        ShowButtons(type, reference);
    }

    /// <summary>
    /// Shows all buttons in the UI.
    /// </summary>
    private static void ShowButtons(Type type, object? reference)
    {
        ImGui.PushID("Buttons");

        int i = 0;

        // Iterate all methods
        foreach (MethodInfo method in type.GetMethods(BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public))
        {
            var showButton = method.GetCustomAttribute<ShowButtonAttribute>();

            if (showButton == null)
                continue;

            if (Application.IsInEditMode && !showButton.Visibility.HasFlag(ButtonVisibility.InEditMode))
                continue;
        
            if (Application.IsInPlayMode && !showButton.Visibility.HasFlag(ButtonVisibility.InPlayMode))
                continue;

            i++;
            ImGui.PushID(i);

            ImGui.TableNextRow();
            ImGui.TableSetColumnIndex(0);

            if (method.GetParameters().Length > 0)
            {
                Log.Error($"Method {method.Name} cannot be executed from editor, because it expects arguments.");
            }
            else if (ImGui.Button(showButton.ButtonText))
            {
                try
                {
                    method.Invoke(reference, null);
                }
                catch (TargetInvocationException ex)
                {
                    Log.Exception(ex.InnerException ?? ex);
                }
                catch (Exception ex)
                {
                    Log.Exception(ex);
                }                
            }
    
            ImGui.PopID();
        }

        ImGui.PopID();
    }

    struct ListPayload
    {
        public IList List;
        public int Element;
    }

    private static object? ShowListEditor(Type fieldType, object? fieldValue, string fieldName)
    {
        Type elementType = fieldType.GenericTypeArguments[0];

        void AddElement(IList? list, out object? newList)
        {
            newList = DidNotChange;

            if (list == null)
            {
                newList = Activator.CreateInstance(fieldType);
                list = newList as IList;

                Debug.Assert(list != null);
            }
            
            try
            {
                object? newElement = ActivatorExtension.CreateDefaultValue(elementType);
                list?.Add(newElement);
            }
            catch (Exception ex)
            {
                Log.Error($"Failed to add new element to list: {ex}");
            }
        }

        void RemoveElement(IList? list, out object? newList)
        {
            newList = DidNotChange;

            if (list == null)
                return;

            if (list.Count == 0)
            {
                newList = null;
            }
            else
            {
                list.RemoveAt(list.Count - 1);
            }
        }

        return ShowGenericListEditor(fieldType, elementType, (IEnumerable?)fieldValue, fieldName, 
            AddElement, RemoveElement);
    }

    private static object? ShowArrayEditor(Type fieldType, object? fieldValue, string fieldName)
    {
        Debug.Assert(fieldType.IsArray);

        Type? elementType = fieldType.GetElementType();

        Debug.Assert(elementType != null);

        Array? myArray = fieldValue as Array;
        
        if (myArray?.Rank > 1)
        {
            throw new NotImplementedException("Multidimensional arrays are not yet supported.");
        }

        void AddElement(IList? list, out object? newList)
        {
            newList = DidNotChange;

            int newIndex = 0;

            if (list == null)
            {
                newList = Array.CreateInstance(elementType, 1);
            }
            else
            {
                newIndex = list.Count;

                Array newArray = Array.CreateInstance(elementType, list.Count + 1);
                Array.Copy((Array)list, newArray, list.Count);

                newList = newArray;
            }
            
            object? newElement = ActivatorExtension.CreateDefaultValue(elementType!);
            ((IList)newList)[newIndex] = newElement;
        }

        void RemoveElement(IList? list, out object? newList)
        {
            newList = DidNotChange;

            if (list == null)
                return;

            if (list.Count == 0)
            {
                newList = null;
            }
            else
            {
                Array newArray = Array.CreateInstance(elementType, list.Count - 1);
                Array.Copy((Array)list, newArray, newArray.Length);

                newList = newArray;
            }
        }

        return ShowGenericListEditor(fieldType, elementType!, (IEnumerable?)fieldValue, fieldName, 
            AddElement, RemoveElement);
    }

    public delegate void ModifyList(IList? currentList, out object? oldList);

    private static object? ShowGenericListEditor(Type listType, Type elementType, IEnumerable? list, string fieldName, 
        ModifyList addElement, ModifyList removeElement)
    {
        object? newList = DidNotChange;
        IList? myList = list as IList;

        ImGui.BeginDisabled(myList == null);
        
        if (myList == null)
            ImGui.SetNextItemOpen(false);

        bool listOpen = ImGui.TreeNodeEx(fieldName, ImGuiTreeNodeFlags.AllowOverlap | ImGuiTreeNodeFlags.SpanAllColumns | ImGuiTreeNodeFlags.Framed);
        
        ImGui.EndDisabled();
        
        ImGui.TableSetColumnIndex(1);

        var addButtonWidth = ImGui.CalcTextSize("+").X + 2 * ImGui.GetStyle().FramePadding.X;
        var removeButtonWidth = ImGui.CalcTextSize("-").X + 2 * ImGui.GetStyle().FramePadding.X;
        
        // TODO: Problem: when opening the list the buttons will move

        ImGui.SameLine(ImGui.GetContentRegionAvail().X - addButtonWidth - ImGui.GetStyle().FramePadding.X - removeButtonWidth);
        
        if (ImGui.SmallButton("+"))
        {
            addElement(myList, out newList);
        }

        ImGuiExtension.AttachTooltip("Add a new Element at the end of the list.");

        ImGui.SameLine(ImGui.GetContentRegionAvail().X - removeButtonWidth);

        ImGui.BeginDisabled(myList == null);

        if (ImGui.SmallButton("-"))
        {
            removeElement(myList, out newList);
        }

        ImGuiExtension.AttachTooltip("Remove the last Element from the list.");

        ImGui.EndDisabled();

        if (listOpen)
        {
            Debug.Assert(myList != null, "Opened tree node even though the list is null!");
            
            // Returns true if something was dropped into the droptarget
            bool DropTarget(int insertIndex, string tooltip)
            {
                bool dropped = false;

                if (ImGui.BeginDragDropTarget())
                {
                    ImGui.SetTooltip(tooltip);

                    var payloadPtr = ImGui.AcceptDragDropPayload("SCRIPT_EDITOR_LIST_ELEMENT");

                    unsafe
                    {
                        if (payloadPtr.NativePtr != null)
                        {
                            ref ListPayload payload = ref Unsafe.AsRef<ListPayload>((void*)payloadPtr.Data);

                            // Make sure the index is still correct
                            if (payload.Element < myList!.Count)
                            {
                                object item = myList[payload.Element];

                                myList.RemoveAt(payload.Element);

                                if (payload.Element >= insertIndex)
                                    myList.Insert(insertIndex, item);
                                else
                                    // If the original index is before the insert index, the insert index will be moved after removing the element
                                    // thus we have to subtract one.
                                    myList.Insert(insertIndex - 1, item);

                                dropped = true;
                            }
                        }
                    }

                    ImGui.EndDragDropTarget();
                }

                return dropped;
            }

            //// Drop at index 0
            //ImGui.Separator();
            //DropTarget(0, "Drop before Element 0.");
            
            bool orderChanged = false;
            
            for (int i = 0, id = 0; i < myList!.Count; i++, id++)
            {
                ImGui.PushID(id);

                object element = myList[i];

                BeginNewRow();

                // A Bullet point to grab the element
                ImGuiExtension.ListElementGrabber();

                if (ImGui.BeginDragDropSource(ImGuiDragDropFlags.SourceAllowNullID))
                {
                    unsafe
                    {
                        ListPayload payload = new() { List = myList, Element = i };

                        ImGui.SetDragDropPayload("SCRIPT_EDITOR_LIST_ELEMENT", (IntPtr)Unsafe.AsPointer(ref payload), (uint)Unsafe.SizeOf<ListPayload>());
                    }

                    ImGui.SetTooltip($"Move Element {i}");

                    ImGui.EndDragDropSource();
                }

                orderChanged |= DropTarget(i, $"Drop before Element {i}.");

                if (ImGui.BeginPopupContextWindow($"ListElementContext{i}"))
                {
                    if (ImGui.MenuItem($"Remove Element {i}"))
                    {
                        myList.RemoveAt(i);
                        i--;
                        ImGui.EndPopup();
                        ImGui.PopID();
                        continue;
                    }

                    ImGui.EndPopup();
                }

                StartNewProperty_NewRow = false;
                object? newValue = ShowFieldEditor(element, element?.GetType() ?? elementType, $"Element {i}");

                // Don't apply changes, when the order changed
                if (newValue != DidNotChange && !orderChanged)
                {
                    myList[i] = newValue;
                }

                //// Drop after current element
                //ImGui.Separator();
                //orderChanged |= DropTarget(i + 1, $"Drop after Element {i}.");

                ImGui.PopID();
            }

            ImGui.TreePop();
        }

        return newList;
    }

    private static T ReadStaticField<T>(string name)
    {
        FieldInfo? field = typeof(T).GetField(name, BindingFlags.Public | BindingFlags.Static);
        
        if (field == null)
        {
            throw new InvalidOperationException($"Type {typeof(T).Name} has no static field \"{name}\"");
        }

        return (T)field.GetValue(null);
    }
}
