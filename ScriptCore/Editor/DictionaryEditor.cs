using GlitchyEngine.Extensions;
using ImGuiNET;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
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
        object? newDictionary = EntityEditor.DidNotChange;
        IDictionary? dictionary = reference as IDictionary;
        
        Type keyType = fieldType.GetGenericArguments()[0];
        Type valueType = fieldType.GetGenericArguments()[1];
        
        
        ImGui.BeginDisabled(dictionary == null);
        
        // Open dictionary if we create a new value inside it
        if (ReferenceEquals(_dictionaryForNewValue, dictionary))
            ImGui.SetNextItemOpen(true);

        // Close dictionary if it is null
        if (dictionary == null)
            ImGui.SetNextItemOpen(false);

        
        bool listOpen = ImGui.TreeNodeEx(fieldName, ImGuiTreeNodeFlags.AllowOverlap | ImGuiTreeNodeFlags.SpanAllColumns | ImGuiTreeNodeFlags.Framed);
        
        ImGui.EndDisabled();
        
        var addButtonWidth = ImGui.CalcTextSize("+").X + 2 * ImGui.GetStyle().FramePadding.X;
        var removeButtonWidth = ImGui.CalcTextSize("x").X + 2 * ImGui.GetStyle().FramePadding.X;

        ImGui.TableSetColumnIndex(1);

        ImGui.SameLine(ImGui.GetContentRegionAvail().X - addButtonWidth - removeButtonWidth - ImGui.GetStyle().FramePadding.X * 2);

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
        
        ImGui.SameLine(ImGui.GetContentRegionAvail().X - removeButtonWidth - ImGui.GetStyle().FramePadding.X);
        
        ImGui.BeginDisabled(dictionary == null);

        if (ImGui.SmallButton("x"))
        {
            if (dictionary != null)
            {
                newDictionary = null;
            }
        }

        ImGuiExtension.AttachTooltip("Deletes the dictionary.");

        ImGui.EndDisabled();

        
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

                EntityEditor.BeginNewRow();

                if (entry.Key == _keyLastCreated)
                {
                    // The current key is the one that was last created. Open the tree node.
                    ImGui.SetNextItemOpen(true);
                    _keyLastCreated = null;
                }

                bool isEntryOpen = ImGui.TreeNodeEx($"Entry {id}", ImGuiTreeNodeFlags.SpanAllColumns | ImGuiTreeNodeFlags.AllowOverlap);

                ImGui.TableSetColumnIndex(1);

                ImGui.SameLine(ImGui.GetContentRegionAvail().X - removeButtonWidth);

                if (ImGui.SmallButton("-"))
                {
                    keysToDelete.Add(entry.Key!);
                }

                ImGuiExtension.AttachTooltip("Remove the last Element from the list.");

                if (isEntryOpen)
                {
                    //ImGui.SameLine();

                    object? newKey = EntityEditor.ShowFieldEditor(entry.Key, entry.Key?.GetType() ?? keyType, "Key");

                    if (newKey != EntityEditor.DidNotChange && newKey != null)
                    {
                        keysToDelete.Add(entry.Key!);
                        newEntries.Add(new DictionaryEntry(newKey, entry.Value));
                    }

                    object? newValue = EntityEditor.ShowFieldEditor(entry.Value, entry.Value?.GetType() ?? valueType, "Value");

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
                EntityEditor.BeginNewRow();

                ImGui.PushID("NewEntry");

                ImGui.SetNextItemOpen(true);
                
                bool isEntryOpen = ImGui.TreeNodeEx($"New Entry", ImGuiTreeNodeFlags.SpanAllColumns | ImGuiTreeNodeFlags.DefaultOpen | ImGuiTreeNodeFlags.AllowOverlap);

                ImGui.TableSetColumnIndex(1);

                ImGui.SameLine(ImGui.GetContentRegionAvail().X - removeButtonWidth);

                if (ImGui.SmallButton("-"))
                {
                    _dictionaryForNewValue = null;
                    _newDictionaryValue = new();
                }

                ImGuiExtension.AttachTooltip("Remove the Entry from the dictionary");

                if (isEntryOpen)
                {
                    object? newKey = EntityEditor.ShowFieldEditor(_newDictionaryValue.Key, keyType, "Key");

                    if (newKey != EntityEditor.DidNotChange && newKey != null)
                    {
                        newEntries.Add(new DictionaryEntry(newKey, _newDictionaryValue.Value));
                        _dictionaryForNewValue = null;
                        _newDictionaryValue = new();
                        _keyLastCreated = newKey;
                    }

                    object? newValue = EntityEditor.ShowFieldEditor(_newDictionaryValue.Value, _newDictionaryValue.Value?.GetType() ?? valueType, "Value");

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
