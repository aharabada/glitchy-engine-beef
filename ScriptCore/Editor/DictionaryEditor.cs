using GlitchyEngine.Extensions;
using ImGuiNET;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.CompilerServices;

namespace GlitchyEngine.Editor;

[CustomEditor(typeof(Dictionary<,>))]
public class DictionaryEditor
{
    private static object? _dictionaryForNewValue = null;
    private static DictionaryEntry _newDictionaryValue = new();
    private static object? _keyLastCreated = null;

    public static object? ShowEditor(object? reference, Type fieldType, string fieldName)
    {
        object newDictionary = EntityEditor.DidNotChange;
        IDictionary? dictionary = reference as IDictionary;
        
        Type keyType = fieldType.GetGenericArguments()[0];
        Type valueType = fieldType.GetGenericArguments()[1];

        // The buttons should always be visible -> save whether the node is open
        // If we have no instance, the user shouldn't be able to open the list
        bool listOpen = ImGui.TreeNodeEx(fieldName,  ImGuiTreeNodeFlags.AllowOverlap | ImGuiTreeNodeFlags.SpanFullWidth |
            (dictionary == null ? ImGuiTreeNodeFlags.Leaf | ImGuiTreeNodeFlags.NoTreePushOnOpen : ImGuiTreeNodeFlags.Framed));

        if (dictionary == null)
            listOpen = false;

        var addButtonWidth = ImGui.CalcTextSize("+").X + 2 * ImGui.GetStyle().FramePadding.X;
        var removeButtonWidth = ImGui.CalcTextSize("-").X + 2 * ImGui.GetStyle().FramePadding.X;

        ImGui.SameLine(ImGui.GetWindowContentRegionMax().X - addButtonWidth - ImGui.GetStyle().FramePadding.X);

        if (ImGui.SmallButton("+"))
        {
            if (dictionary == null)
            {
                newDictionary = Activator.CreateInstance(fieldType);
                dictionary = newDictionary as IDictionary;

                Debug.Assert(dictionary != null);
            }

            _dictionaryForNewValue = dictionary;

            _newDictionaryValue = new DictionaryEntry();
        }

        ImGuiExtension.AttachTooltip("Add a new Entry to the dictionary.");
        
        if (listOpen)
        {
            Debug.Assert(dictionary != null, "Opened tree node even though it should have been a leaf!");

            int id = 0;

            List<DictionaryEntry> newEntries = new();
            List<object> keysToDelete = new();

            foreach (DictionaryEntry entry in dictionary!)
            {
                id++;
                ImGui.PushID(id);

                if (entry.Key == _keyLastCreated)
                {
                    // The current key is the one that was last created. Open the tree node.
                    ImGui.SetNextItemOpen(true);
                    _keyLastCreated = null;
                }

                bool isEntryOpen = ImGui.TreeNode("");

                ImGui.SameLine(ImGui.GetWindowContentRegionMax().X - removeButtonWidth);

                if (ImGui.SmallButton("-"))
                {
                    keysToDelete.Add(entry.Key!);
                }

                ImGuiExtension.AttachTooltip("Remove the last Element from the list.");

                if (isEntryOpen)
                {
                    object newKey = EntityEditor.ShowFieldEditor(entry.Key, entry.Key?.GetType() ?? keyType, "Key");

                    if (newKey != EntityEditor.DidNotChange)
                    {
                        keysToDelete.Add(entry.Key!);
                        newEntries.Add(new DictionaryEntry(newKey, entry.Value));
                    }

                    object newValue = EntityEditor.ShowFieldEditor(entry.Value, entry.Value?.GetType() ?? valueType, "Value");

                    if (newValue != EntityEditor.DidNotChange)
                    {
                        keysToDelete.Add(entry.Key!);
                        newEntries.Add(new DictionaryEntry(entry.Key!, newValue));
                    }

                    ImGui.TreePop();
                }

                ImGui.PopID();
            }


            if (ReferenceEquals(_dictionaryForNewValue, dictionary))
            {
                ImGui.PushID("NewEntry");

                ImGui.SetNextItemOpen(true);
                bool isEntryOpen = ImGui.TreeNode("");

                ImGui.SameLine(ImGui.GetWindowContentRegionMax().X - removeButtonWidth);

                if (ImGui.SmallButton("-"))
                {
                    _dictionaryForNewValue = null;
                    _newDictionaryValue = new();
                }

                ImGuiExtension.AttachTooltip("Remove the Entry from the dictionary");

                if (isEntryOpen)
                {
                    object newKey = EntityEditor.ShowFieldEditor(_newDictionaryValue.Key, keyType, "Key");

                    if (newKey != EntityEditor.DidNotChange)
                    {
                        newEntries.Add(new DictionaryEntry(newKey, _newDictionaryValue.Value));
                        _dictionaryForNewValue = null;
                        _newDictionaryValue = new();
                        _keyLastCreated = newKey;
                    }

                    object newValue = EntityEditor.ShowFieldEditor(_newDictionaryValue.Value, _newDictionaryValue.Value?.GetType() ?? valueType, "Value");

                    if (newValue != EntityEditor.DidNotChange)
                    {
                        _newDictionaryValue.Value = newValue;
                    }

                    ImGui.TreePop();
                }

                ImGui.PopID();
            }

            foreach (object key in keysToDelete)
            {
                dictionary.Remove(key);
            }

            foreach (DictionaryEntry newEntry in newEntries)
            {
                dictionary.Add(newEntry.Key, newEntry.Value);
            }

            ImGui.TreePop();
        }

        return newDictionary;
    }
}
