using System;
using System.Collections.Generic;
using System.Reflection;
using System.Text;
using GlitchyEngine.Core;
using ImGuiNET;

namespace GlitchyEngine.Editor;

internal class EntityEditor
{
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
                Type fieldType = field.FieldType;

                if (fieldType.IsGenericType)
                {
                    if (fieldType.GetGenericTypeDefinition() == typeof(List<>))
                    {
                        ImGui.Text($"{field.Name} List");
                    }
                    else if (fieldType.GetGenericTypeDefinition() == typeof(Dictionary<,>))
                    {
                        ImGui.Text($"{field.Name} Dictionary");
                    }
                }
                else if (fieldType.IsArray)
                {
                    ImGui.Text($"{field.Name} Array");
                }
                else if (fieldType.IsEnum)
                {
                    ImGui.Text($"{field.Name} Enum");
                }
                else if (fieldType.IsPrimitive)
                {
                    ImGui.Text($"{field.Name} Primitive");

                    if (reference != null)
                    {
                        if (fieldType == typeof(float))
                        {
                            float f = (float)field.GetValue(reference);
                            if (ImGui.DragFloat(field.Name, ref f))
                            {
                                field.SetValue(reference, f);
                            }
                        }
                    }
                }
                else if (fieldType.IsValueType)
                {
                    // Struct
                    if (ImGui.TreeNode(field.Name))
                    {
                        object @struct = (reference != null) ? field.GetValue(reference) : null;

                        ShowEditor(fieldType, @struct);

                        if (@struct != null)
                        {
                            field.SetValue(reference, @struct);
                        }

                        ImGui.TreePop();
                    }
                        
                }
                else if (fieldType.IsSubclassOf(typeof(Entity)) || fieldType == typeof(Entity))
                {
                    // TODO: Show entity drop target
                    ImGui.Text($"{field.Name} Entity ({fieldType.Name})");
                }
                else if (fieldType.IsSubclassOf(typeof(Component)))
                {
                    // TODO: Show component drop target
                    ImGui.Text($"{field.Name} Component ({fieldType.Name})");
                }
                else
                {
                    if (ImGui.TreeNode(field.Name))
                    {
                        // TODO: Button to create / destroy instance
                        
                        object @class = (reference != null) ? field.GetValue(reference) : null;

                        ShowEditor(fieldType, @class);
                        ImGui.TreePop();
                    }
                }
            }
            
            ImGui.PopID();
        }
    }
}
