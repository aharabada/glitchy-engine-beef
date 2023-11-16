using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text;
using GlitchyEngine.Core;
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
            return true;

        var showInEditorAttribute = fieldInfo.GetCustomAttribute<ShowInEditorAttribute>();

        if (showInEditorAttribute != null)
            return true;

        return false;
    }
    
    public static void ShowDefaultEntityEditor(UUID entityId, Type entityType)
    {
        object instance = ScriptGlue.Entity_GetScriptInstance(entityId);

        ShowEditor(entityType, instance);
    }

    public static object ShowFieldEditor(object reference, Type fieldType, string fieldName)
    {
        if (fieldType.IsGenericType)
        {
            if (fieldType.GetGenericTypeDefinition() == typeof(List<>))
            {
                //ImGui.Text($"{fieldName} List");

                //object @class = (reference != null) ? field.GetValue(reference) : null;

                //if (@class != null)
                // ShowListEditor(@class, fieldName);
                if (reference != null)
                    ShowListEditor(reference, fieldName);
            }
            else if (fieldType.GetGenericTypeDefinition() == typeof(Dictionary<,>))
            {
                ImGui.Text($"{fieldName} Dictionary");
            }
        }
        else if (fieldType.IsArray)
        {
            ImGui.Text($"{fieldName} Array");
        }
        else if (fieldType.IsEnum)
        {
            ImGui.Text($"{fieldName} Enum");
        }
        else if (fieldType.IsPrimitive)
        {
            ImGui.Text($"{fieldName} Primitive");

            if (reference != null)
            {
                if (fieldType == typeof(float))
                {
                    float f = (float)reference;
                    if (ImGui.DragFloat(fieldName, ref f))
                    {
                        return f;
                    }
                }
                else if (fieldType == typeof(int))
                {
                    int f = (int)reference;
                    if (ImGui.DragInt(fieldName, ref f))
                    {
                        return f;
                    }
                }
            }
        }
        else if (fieldType.IsValueType)
        {
            // Struct
            if (ImGui.TreeNode(fieldName))
            {
                //object @struct = (reference != null) ? field.GetValue(reference) : null;

                ShowEditor(fieldType, reference);

                //if (@struct != null)
                //{
                //    field.SetValue(reference, @struct);
                //}

                ImGui.TreePop();

                return reference;
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
        else
        {
            if (ImGui.TreeNode(fieldName))
            {
                //object @class = (reference != null) ? field.GetValue(reference) : null;

                //if (@class == null)
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
                                //return instance;
                                //field.SetValue(reference, instance);
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
                        //return null;
                        //field.SetValue(reference, null);
                    }
                }

                //if (@class == null)
                if (reference == null)
                    ImGui.Text("(NULL)");
                else
                    ShowEditor(reference.GetType(), reference);

                ImGui.TreePop();
            }
        }

        return DidNotChange;
    }

    public static void ShowEditor(Type type, object reference)
    {
        T GetValue<T>(FieldInfo fieldInfo)
        {
            return default;
        }

        int i = 0;

        foreach (FieldInfo field in type.GetFields(BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public))
        {
            i++;
            ImGui.PushID(i);

            if (ShowFieldInEditor(field))
            {
                Log.Info(field.Name);

                object value = field.GetValue(reference);

                object newValue = ShowFieldEditor(value, value?.GetType() ?? field.FieldType, field.Name);

                if (newValue != DidNotChange)
                {
                    // Reference was changed inside Field Editor -> write back to field (only necessary for value types)
                    field.SetValue(reference, newValue);
                }
            }
            
            ImGui.PopID();
        }
    }

    private static void ShowListEditor(object list, string fieldName)
    {
        IList myList = list as IList;

        if (myList == null)
        {
            Log.Error($"List \"{fieldName}\" is not an IList");
            return;
        }

        Type elementType = list.GetType().GenericTypeArguments[0];

        // The buttons should always be visible -> save whether the node is open
        bool listOpen = ImGui.TreeNode(fieldName);
        
        var addButtonWidth = ImGui.CalcTextSize("+").X + 2 * ImGui.GetStyle().FramePadding.X;
        var removeButtonWidth = ImGui.CalcTextSize("-").X + 2 * ImGui.GetStyle().FramePadding.X;

        ImGui.SameLine(ImGui.GetWindowContentRegionMax().X - addButtonWidth - ImGui.GetStyle().FramePadding.X - removeButtonWidth);

        if (ImGui.SmallButton("+"))
        {
            object newElement = Activator.CreateInstance(elementType);
            myList.Add(newElement);
        }

        ImGui.SetTooltip("Add a new Element at the end of the list.");
            
        ImGui.SameLine(ImGui.GetWindowContentRegionMax().X - removeButtonWidth);

        if (ImGui.SmallButton("-"))
        {
            myList.RemoveAt(myList.Count - 1);
        }
        
        ImGui.SetTooltip("Remove the last Element from the list.");

        if (listOpen)
        {
            for (int i = 0; i < myList.Count; i++)
            {
                if (ImGui.TreeNodeEx($"Element {i}"))
                {
                    object element = myList[i];

                    object newValue = ShowFieldEditor(element, element.GetType(), $"Element {i}");

                    if (newValue != DidNotChange)
                    {
                        myList[i] = newValue;
                    }

                    ImGui.TreePop();
                }
            }

            ImGui.TreePop();
        }
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
}
