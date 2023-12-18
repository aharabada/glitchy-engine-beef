using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Numerics;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Text;
using GlitchyEngine.Core;
using GlitchyEngine.Extensions;
using GlitchyEngine.Math;
using ImGuiNET;

namespace GlitchyEngine.Editor;

class DidNotChange
{
}

internal class EntityEditor
{
    private static readonly DidNotChange DidNotChange = new DidNotChange();

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
    
    public static void ShowDefaultEntityEditor(UUID entityId, Type entityType)
    {
        // TODO: Call custom editors here!

        ScriptGlue.Entity_GetScriptInstance(entityId, out object instance);

        ShowEditor(entityType, instance);
    }

    private static T GetAttribute<T>(IEnumerable<Attribute> attributes) where T : Attribute
    {
        return (T)attributes?.FirstOrDefault(a => a is T);
    }

    private static object ShowPrimitiveEditor(object reference, Type fieldType, string fieldName, IEnumerable<Attribute> attributes)
    {
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

            RangeAttribute range = GetAttribute<RangeAttribute>(attributes);

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
                MinimumAttribute minimum = GetAttribute<MinimumAttribute>(attributes);
                MaximumAttribute maximum = GetAttribute<MaximumAttribute>(attributes);
                
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

            var value = (T)reference;

            if (range?.Slider == true)
            {
                if (ImGui.SliderScalar(fieldName, dataType, (IntPtr)(&value), (IntPtr)(&min), (IntPtr)(&max)))
                {
                    newValue = value;
                }
            }
            else
            {
                if (ImGui.DragScalar(fieldName, dataType, (IntPtr)(&value), dragSpeed, (IntPtr)(&min), (IntPtr)(&max)))
                {
                    newValue = value;
                }
            }
        }

        // TODO: allow editing in edit-mode
        if (reference != null)
        {
            if (fieldType == typeof(bool))
            {
                bool value = (bool)reference;
                if (ImGui.Checkbox(fieldName, ref value))
                    newValue = value;
            }
            else if (fieldType == typeof(char))
            {
                unsafe
                {
                    char value = (char)reference;

                    // TODO: Allow entering chars like '\0', '\n', etc...
                    if (ImGui.InputText(fieldName, (IntPtr)(&value), 2))
                        newValue = value;
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
        }

        return newValue;
    }

    private static object ShowEnumEditor(object reference, Type fieldType, string fieldName)
    {
        object newValue = DidNotChange;

        if (ImGui.BeginCombo(fieldName, reference.ToString()))
        {
            foreach (object enumValue in Enum.GetValues(fieldType))
            {
                if (ImGui.Selectable(enumValue.ToString(), enumValue == reference))
                {
                    newValue = enumValue;
                }
            }

            ImGui.EndCombo();
        }

        return newValue;
    }

    public static object ShowFieldEditor(object reference, Type fieldType, string fieldName, IEnumerable<Attribute> attributes = null)
    {
        ReadonlyAttribute readonlyAttribute = GetAttribute<ReadonlyAttribute>(attributes);
        
        ImGui.BeginDisabled(readonlyAttribute != null);

        object newValue = DidNotChange;

        if (fieldType.IsGenericType)
        {
            if (fieldType.GetGenericTypeDefinition() == typeof(List<>))
            {
                newValue = ShowListEditor(fieldType, reference, fieldName);
            }
            else if (fieldType.GetGenericTypeDefinition() == typeof(Dictionary<,>))
            {
                ImGui.Text($"{fieldName} Dictionary");
            }
            else
            {
                // TODO: Try to use a custom editor
                ImGui.TextColored(new Vector4(1, 0, 0, 1), $"{fieldName}: Type {fieldType} is not implemented.");
            }
        }
        else if (fieldType.IsArray)
        {
            ImGui.Text($"{fieldName} Array");
        }
        else if (fieldType.IsEnum)
        {
            newValue = ShowEnumEditor(reference, fieldType, fieldName);
        }
        else if (fieldType.IsPrimitive)
        {
            newValue = ShowPrimitiveEditor(reference, fieldType, fieldName, attributes);
        }
        else if (fieldType.IsValueType)
        {
            if (fieldType == typeof(bool2))
            {
                bool2 value = (bool2)reference;
                    
                ImGui.TextUnformatted(fieldName);

                ImGui.SameLine();

                if (ImGui.Checkbox($"##{fieldName}X", ref value.X))
                    newValue = value;
                    
                ImGui.SameLine();

                if (ImGui.Checkbox($"##{fieldName}Y", ref value.Y))
                    newValue = value;
            }
            
            ImGui.EndDisabled();

            // Struct
            if (ImGui.TreeNode(fieldName))
            {
                ImGui.BeginDisabled(readonlyAttribute != null);

                ShowEditor(fieldType, reference);
                
                ImGui.TreePop();

                newValue = reference;
            }
            else
            {
                ImGui.BeginDisabled(readonlyAttribute != null);
            }
        }
        else if (fieldType.IsSubclassOf(typeof(Entity)) || fieldType == typeof(Entity))
        {
            // TODO: Show entity drop target
            ImGui.Text($"{fieldName} Entity ({fieldType.Name})");
        }
        else if (fieldType.IsSubclassOf(typeof(Component)))
        {
            // TODO: Show component drop target
            ImGui.Text($"{fieldName} Component ({fieldType.Name})");
        }
        else if (fieldType == typeof(string))
        {
            newValue = ShowStringEditor(reference, fieldType, fieldName, attributes);
        }
        else
        {
            ImGui.EndDisabled();

            if (ImGui.TreeNode(fieldName))
            {
                ImGui.BeginDisabled(readonlyAttribute != null);

                if (reference == null)
                {
                    ImGui.SameLine(ImGui.GetWindowContentRegionMax().X - ImGui.CalcTextSize("Create").X - 2 * ImGui.GetStyle().FramePadding.X);

                    if (ImGui.BeginCombo("Create", "Create", ImGuiComboFlags.HeightSmall | ImGuiComboFlags.NoArrowButton))
                    {
                        foreach (Type t in FindDerivedTypes(fieldType))
                        {
                            if (ImGui.Selectable(t.Name))
                            {
                                object instance = Activator.CreateInstance(t);
                                newValue = instance;
                            }
                        }

                        ImGui.EndCombo();
                    }
                }
                else
                {
                    ImGui.SameLine(ImGui.GetWindowContentRegionMax().X - ImGui.CalcTextSize("Remove").X - 2 * ImGui.GetStyle().FramePadding.X);

                    if (ImGui.SmallButton("Remove"))
                    {
                        newValue = null;
                    }
                }

                if (reference == null)
                    ImGui.Text("(NULL)");
                else
                    ShowEditor(reference.GetType(), reference);

                ImGui.TreePop();
            }
            else
            {
                ImGui.BeginDisabled(readonlyAttribute != null);
            }
        }

        ImGui.EndDisabled();

        return newValue;
    }

    private static object ShowStringEditor(object reference, Type fieldType, string fieldName, IEnumerable<Attribute> attributes)
    {
        object newValue = DidNotChange;

        TextFieldAttribute textField = GetAttribute<TextFieldAttribute>(attributes);

        string value = reference as string ?? $"{float.MinValue}";

        if (textField?.Multiline == true)
        {
            ImGui.Text(fieldName);
            if (ImGui.InputTextMultiline($"##{fieldName}", ref value, 1000, new Vector2(-1.0f, ImGui.GetTextLineHeight() * textField.TextFieldLines)))
                newValue = value;
        }
        else
        {
            if (ImGui.InputText(fieldName, ref value, 1000))
                newValue = value;
        }

        return newValue;
    }

    public static void ShowEditor(Type type, object reference)
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

                object newValue = ShowFieldEditor(value, value?.GetType() ?? field.FieldType, field.Name, attributes);

                if (newValue != DidNotChange)
                {
                    // Reference was changed inside Field Editor -> write back to field (only necessary for value types)
                    field.SetValue(reference, newValue);
                }
            }
            
            ImGui.PopID();
        }
        
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

            if (method.GetParameters().Length > 0)
            {
                Log.Error($"Method {method.Name} cannot be executed from editor, because it expects arguments.");
            }
            else if (ImGui.Button(showButton.ButtonText))
            {
                method.Invoke(reference, null);
            }
    
            ImGui.PopID();
        }
    }

    struct ListPayload
    {
        public IList List;
        public int Element;
    }

    private static object ShowListEditor(Type fieldType, object list, string fieldName)
    {
        object newList = DidNotChange;
        IList myList = list as IList;

        Type elementType = fieldType.GenericTypeArguments[0];

        // The buttons should always be visible -> save whether the node is open
        // If we have no instance, the user shouldn't be able to open the list
        bool listOpen = ImGui.TreeNodeEx(fieldName,
            myList == null ? ImGuiTreeNodeFlags.Leaf | ImGuiTreeNodeFlags.NoTreePushOnOpen : ImGuiTreeNodeFlags.Framed);

        if (myList == null)
            listOpen = false;

        var addButtonWidth = ImGui.CalcTextSize("+").X + 2 * ImGui.GetStyle().FramePadding.X;
        var removeButtonWidth = ImGui.CalcTextSize("-").X + 2 * ImGui.GetStyle().FramePadding.X;

        ImGui.SameLine(ImGui.GetWindowContentRegionMax().X - addButtonWidth - ImGui.GetStyle().FramePadding.X - removeButtonWidth);

        if (ImGui.SmallButton("+"))
        {
            if (myList == null)
            {
                newList = Activator.CreateInstance(fieldType);
                myList = newList as IList;

                Debug.Assert(myList != null);
            }

            object newElement = Activator.CreateInstance(elementType);
            myList.Add(newElement);
        }

        ImGuiExtension.AttachTooltip("Add a new Element at the end of the list.");

        ImGui.SameLine(ImGui.GetWindowContentRegionMax().X - removeButtonWidth);

        ImGui.BeginDisabled(myList == null || myList.Count == 0);

        if (ImGui.SmallButton("-"))
        {
            myList!.RemoveAt(myList.Count - 1);
        }

        ImGuiExtension.AttachTooltip("Remove the last Element from the list.");

        ImGui.EndDisabled();

        if (listOpen)
        {
            Debug.Assert(myList != null, "Opened tree node even though it should have been a leaf!");

            /// Returns true if something was dropped into the droptarget
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
                            if (payload.Element < myList.Count)
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

            // Drop at index 0
            ImGui.Separator();
            DropTarget(0, "Drop before Element 0.");

            bool orderChanged = false;

            for (int i = 0, id = 0; i < myList.Count; i++, id++)
            {
                ImGui.PushID(id);

                object element = myList[i];

                // A Bullet point to grab the element
                ImGui.Bullet();
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
                
                ImGui.SameLine();

                object newValue = ShowFieldEditor(element, element.GetType(), $"Element {i}");

                // Don't apply changes, when the order changed
                if (newValue != DidNotChange && !orderChanged)
                {
                    myList[i] = newValue;
                }

                // Drop after current element
                ImGui.Separator();
                
                orderChanged |= DropTarget(i + 1, $"Drop after Element {i}.");

                ImGui.PopID();
            }

            ImGui.TreePop();
        }

        return newList;
    }

    /// <summary>
    /// Enumerates all types that derive from the given type.
    /// </summary>
    /// <param name="baseType"></param>
    /// <returns></returns>
    public static IEnumerable<Type> FindDerivedTypes(Type baseType)
    {
        foreach (Assembly domainAssembly in AppDomain.CurrentDomain.GetAssemblies())
        foreach (Type type in domainAssembly.GetTypes())
        {
            if (baseType.IsAssignableFrom(type) && !type.IsAbstract) yield return type;
        }
    }

    private static T ReadStaticField<T>(string name)
    {
        FieldInfo field = typeof(T).GetField(name, BindingFlags.Public | BindingFlags.Static);
        
        if (field == null)
        {
            throw new InvalidOperationException($"Type {typeof(T).Name} has no static field \"{name}\"");
        }

        return (T)field.GetValue(null);
    }
}
