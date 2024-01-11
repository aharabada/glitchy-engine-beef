#nullable enable

using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using GlitchyEngine.Core;
using GlitchyEngine.Extensions;

namespace GlitchyEngine.Serialization;

/// <summary>
/// Provides Serialization and Deserialization for Dictionaries.
/// </summary>
[CustomSerializer(typeof(Dictionary<,>))]
public static class DictionarySerializer
{
    /// <summary>
    /// Serializes a given Dictionary as a field of <see cref="container"/>.
    /// </summary>
    /// <param name="container">The parent object.</param>
    /// <param name="fieldName">Name of the field in <see cref="container"/></param>
    /// <param name="fieldValue">The dictionary</param>
    /// <param name="fieldType">Type of <see cref="fieldValue"/> or the type of the field if <see cref="fieldValue"/> is <see langword="null"/></param>
    public static void Serialize(SerializedObject container, string fieldName, object? fieldValue, Type fieldType)
    {
        if (fieldValue == null)
        {
            // Write a null pointer early out
            container.AddField(fieldName, SerializationType.ObjectReference, UUID.Zero);
            return;
        }
        
        // Get a container for our dictionary (Note: container is our parent object).
        // isNewContext is true, if our dictionary wasn't serialized so far.
        var (context, isNewContext) = container.GetSerializedObject(fieldValue);

        if (isNewContext)
        {
            Type keyType = fieldType.GetGenericArguments()[0];
            Type valueType = fieldType.GetGenericArguments()[1];

            IDictionary dictionary = (IDictionary)fieldValue;
            ICollection collection = (ICollection)fieldValue;
            
            context.AddField("Count", SerializationType.Int32, collection.Count);

            int index = 0;

            foreach (DictionaryEntry entry in dictionary)
            {
                context.PushScope(index.ToString());

                context.SerializeField("Key", entry.Key, keyType);
                context.SerializeField("Value", entry.Value, valueType);

                context.PopScope();

                index++;
            }
        }
        
        // Write the reference to our dictionary into the field of the parent.
        container.AddField(fieldName, SerializationType.ObjectReference, context.Id);
    }

    /// <summary>
    /// Deserializes a dictionary that is a field of the given <see cref="container"/>.
    /// </summary>
    /// <param name="container">The parent object whose field with <see cref="fieldName"/> is a dictionary.</param>
    /// <param name="fieldName">The name of the field.</param>
    /// <param name="fieldType">The type of the field.</param>
    /// <returns></returns>
    public static object? Deserialize(DeserializationObject container, string fieldName, Type fieldType)
    {
        UUID id = container.GetFieldValue<UUID>(fieldName, SerializationType.ObjectReference);

        if (id == UUID.Zero)
            return null;
        
        // Get serialization container for the instance
        DeserializationObject? deserializedObject = container.GetDeserializedObject(id);

        Type? type = deserializedObject?.StoredType;

        if (type?.IsAssignableTo(fieldType) != true)
            return DeserializationObject.NoValueDeserialized;

        Type keyType = fieldType.GetGenericArguments()[0];
        Type valueType = fieldType.GetGenericArguments()[1];

        int count = deserializedObject!.GetFieldValue<int>("Count", SerializationType.Int32);
        
        // Create instance, pass in capacity
        object? instance = ActivatorExtension.CreateInstanceSafe(type, count);
        
        Debug.Assert(instance != null);

        IDictionary dictionary = (IDictionary)instance!;

        for (int i = 0; i < count; i++)
        {
            deserializedObject.PushScope(i.ToString());

            object? key = deserializedObject.DeserializeField(null, keyType, "Key");
            object? value = deserializedObject.DeserializeField(null, valueType, "Value");

            if (key != null)
            {
                dictionary.Add(key, value);
            }

            deserializedObject.PopScope();
        }

        return instance;
    }
}
