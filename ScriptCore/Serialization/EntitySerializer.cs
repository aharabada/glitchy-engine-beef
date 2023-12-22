using GlitchyEngine.Editor;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Reflection;
using System.Text;
using GlitchyEngine.Core;
using GlitchyEngine.Extensions;

namespace GlitchyEngine.Serialization;

public enum SerializationType : int
{
    None,

    Bool,

    Char,
    String,

    Int8,
    Int16,
    Int32,
    Int64,
    UInt8,
    UInt16,
    UInt32,
    UInt64,

    Float,
    Double,
    Decimal,

    Enum,

    EntityReference,
    ComponentReference,

    ObjectReference
}

public static class EntitySerializer
{
    public class SerializedObject
    {
        private IntPtr _internalContext;

        private UUID _id;

        private Stack<string> _structScope = new();

        private string _structScopeName;

        public Dictionary<object, SerializedObject> SerializedClasses;

        public SerializedObject(IntPtr internalContext, UUID id, Dictionary<object, SerializedObject> serializedClasses)
        {
            _internalContext = internalContext;
            _id = id;
            SerializedClasses = serializedClasses;
        }
        
        private (SerializedObject context, bool newContext) GetSerializedObject(object o)
        {
            SerializedObject context;

            if (SerializedClasses.TryGetValue(o, out context))
                return (context, false);
            
            ScriptGlue.Serialization_CreateObject(_internalContext, out IntPtr contextPtr, out UUID id);

            context = new SerializedObject(contextPtr, id, SerializedClasses);

            SerializedClasses.Add(o, context);

            return (context, true);
        }

        private void PushScope(string name)
        {
            _structScope.Push(name);

            _structScopeName += $"{name}.";
        }

        private void PopScope()
        {
            string scopeToRemove = _structScope.Pop();
            _structScopeName.Remove(_structScopeName.Length - scopeToRemove.Length - 1);
        }

        private void AddField(string fieldName, SerializationType serializationType, object value)
        {
            string completeFieldName = $"{_structScopeName}{fieldName}";

            ScriptGlue.Serialization_SerializeField(_internalContext, serializationType, completeFieldName, value);
        }

        public void Serialize(Entity entity)
        {
            SerializeFields(entity);
        }
        
        private void SerializeFields(object obj)
        {
            Type type = obj.GetType();

            foreach (FieldInfo field in type.GetFields())
            {
                if (!EntitySerializer.SerializeField(field))
                    continue;

                object fieldValue = field.GetValue(obj);
                Type fieldType = fieldValue?.GetType() ?? field.FieldType;

                SerializeField(field.Name, fieldValue, fieldType);
            }
        }

        private void SerializeField(string fieldName, object fieldValue, Type fieldType)
        {
            if (fieldType.IsPrimitive)
            {
                SerializePrimitive(fieldName, fieldValue, fieldType);
            }
            else if (fieldType == typeof(string))
            {
                AddField(fieldName, SerializationType.String, fieldValue.ToString());
            }
            else if (fieldType.IsEnum)
            {
                SerializeEnum(fieldName, fieldValue, fieldType);
            }
            else if (fieldType.IsArray)
            {
                Log.Error($"Array serialization not yet implemented");
            }
            else if (fieldType.IsGenericType)
            {
                if (fieldType.GetGenericTypeDefinition() == typeof(List<>))
                {
                    //SerializeList(fieldName, type, o);
                    Log.Error($"List serialization not yet implemented");
                }
                //else if (fieldType.GetGenericTypeDefinition() == typeof(Dictionary<,>))
                //{
                //    ImGui.Text($"{fieldName} Dictionary");
                //}
                else
                {
                    // TODO: what to do?
                    Log.Error($"Generic class serialization not yet implemented");
                }
            }
            else if (fieldType.IsValueType)
            {
                SerializeStruct(fieldName, fieldValue, fieldType);
            }
            else if (fieldType.IsClass)
            {
                SerializeClass(fieldName, fieldValue, fieldType);
            }
            else
            {
                Log.Error($"Encountered unhandled type \"{fieldType}\" while serializing.");
            }
        }

        private void SerializePrimitive(string fieldName, object fieldValue, Type fieldType)
        {
            Debug.Assert(fieldType.IsPrimitive, $"{fieldType} is not a primitive type.");

            SerializationType type = SerializationType.None;
            
            if (fieldType == typeof(bool))
                type = SerializationType.Bool;
            else if (fieldType == typeof(char))
                type = SerializationType.Char;
            else if (fieldType == typeof(byte))
                type = SerializationType.UInt8;
            else if (fieldType == typeof(sbyte))
                type = SerializationType.Int8;
            else if (fieldType == typeof(ushort))
                type = SerializationType.UInt16;
            else if (fieldType == typeof(short))
                type = SerializationType.Int16;
            else if (fieldType == typeof(uint))
                type = SerializationType.UInt32;
            else if (fieldType == typeof(int))
                type = SerializationType.Int32;
            else if (fieldType == typeof(ulong))
                type = SerializationType.UInt64;
            else if (fieldType == typeof(long))
                type = SerializationType.Int64;
            else if (fieldType == typeof(float))
                type = SerializationType.Float;
            else if (fieldType == typeof(double))
                type = SerializationType.Double;
            else if (fieldType == typeof(decimal))
                type = SerializationType.Decimal;
            else
            {
                Log.Error($"The primitive {fieldType} is not implemented.");
            }

            AddField(fieldName, type, fieldValue);
        }

        private void SerializeEnum(string fieldName, object fieldValue, Type fieldType)
        {
            AddField(fieldName, SerializationType.Enum, fieldValue.ToString());
        }

        private void SerializeStruct(string fieldName, object fieldValue, Type fieldType)
        {
            PushScope(fieldName);

            SerializeFields(fieldValue);

            PopScope();
        }

        private void SerializeClass(string fieldName, object fieldValue, Type fieldType)
        {
            if (typeof(Entity).IsAssignableFrom(fieldType))
            {
                AddField(fieldName, SerializationType.EntityReference, ((Entity)fieldValue)?.UUID ?? UUID.Zero);
            }
            else if (typeof(Component).IsAssignableFrom(fieldType))
            {
                    AddField(fieldName, SerializationType.ComponentReference, ((Component)fieldValue)?.UUID ?? UUID.Zero);
            }
            else
            {
                if (fieldValue == null)
                {
                    AddField(fieldName, SerializationType.ObjectReference, UUID.Zero);
                }
                else
                {
                    var (context, newContext) = GetSerializedObject(fieldValue);

                    if (newContext)
                    {
                        context.SerializeFields(fieldValue);
                    }

                    AddField(fieldName, SerializationType.ObjectReference, context._id);   
                }
            }
        }
    }

    public class SerializationContext
    {
        StringBuilder _builder = new();

        public Dictionary<object, SerializationContext> SerializedClasses = new();

        public UUID ID = UUID.CreateNew();

        private int _indentLevel = 0;

        private void BeginLine()
        {
            for (int i = 0; i < _indentLevel; i++)
                _builder.Append('\t');
        }

        private void WriteLine(string line)
        {
            BeginLine();

            _builder.AppendLine(line);
        }

        private void WriteField(string type, string name, string value)
        {
            BeginLine();

            _builder.AppendFormat("{0} {1} = {2}", type, name, value);
            _builder.Append('\n');
        }

        private void StartBlock()
        {
            WriteLine("{");
            _indentLevel++;
        }

        private void EndBlock()
        {
            Debug.Assert(_indentLevel > 0);
            _indentLevel--;
            WriteLine("}");
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="o"></param>
        /// <returns>A serialization context for the given object. And true, if the context was used before, false otherwise.</returns>
        private (SerializationContext context, bool newContext) GetReferenceTypeContext(object o)
        {
            SerializationContext context;

            if (SerializedClasses.TryGetValue(o, out context))
                return (context, false);
            
            context = new SerializationContext
            {
                SerializedClasses = SerializedClasses,
                // The indentation is arbitrary anyway, this is just for style
                _indentLevel = 1
            };

            SerializedClasses.Add(o, context);

            return (context, true);
        }
        
        private void SerializeArray(string fieldName, Type fieldType, object o)
        {
            Type type = o.GetType();

            Debug.Assert(type.IsArray);

            Type elementType = type.GetElementType();
            
            Debug.Assert(elementType != null);
            
            WriteField(type.ToString(), fieldName, "");

            StartBlock();

            Array array = (Array)o;

            foreach (var element in array)
            {
                Serialize("", elementType, element);
            }

            EndBlock();
        }

        public void SerializeList(string fieldName, Type fieldType, object o)
        {
            Type type = o.GetType();
            
            Debug.Assert(type.IsGenericType);

            Type elementType = type.GetGenericArguments()[0];
            
            WriteField(type.ToString(), fieldName, "");

            StartBlock();

            IList list = (IList)o;

            foreach (var element in list)
            {
                Serialize("", elementType, element);
            }

            EndBlock();
        }
        void SerializeFields(Type objectType, object instance)
        {
            foreach (FieldInfo fieldInfo in objectType.GetFields(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance))
            {
                if (!SerializeField(fieldInfo))
                    continue;

                object value = fieldInfo.GetValue(instance);
                Serialize(fieldInfo.Name, fieldInfo.FieldType, value);
            }
        }


        /// <summary>
        /// 
        /// </summary>
        /// <param name="o"></param>
        /// <param name="shallowEntities">If true, entities will only be serialized as their UUID</param>
        public void Serialize(string fieldName, Type fieldType, object o, bool shallowEntities = true)
        {
            // TODO: is this shortcut valid?
            if (o == null)
            {
                WriteField(fieldType.ToString(), fieldName, "null");
                return;
            }

            Type type = o.GetType();

            if (typeof(Entity).IsAssignableFrom(type))
            {
                if (shallowEntities)
                    WriteField(type.ToString(), fieldName, ((Entity)o).UUID.ToString());
                else
                    SerializeClass(fieldName, type, o);
                    //SerializeFields(type, o);
            }
            else if (typeof(Component).IsAssignableFrom(type))
            {
                WriteField(type.ToString(), fieldName, ((Component)o).UUID.ToString());
            }
            else if (type == typeof(string))
            {
                WriteField(type.ToString(), fieldName, $"\"{(string)o}\"");
            }
            else if (type.IsPrimitive)
            {
                WriteField(type.ToString(), fieldName, o.ToString());
            }
            else if (type.IsEnum)
            {
                WriteField(type.ToString(), fieldName, o.ToString());
            }
            else if (type.IsArray)
            {
                SerializeArray(fieldName, type, o);
            }
            else if (type.IsGenericType)
            {
                if (fieldType.GetGenericTypeDefinition() == typeof(List<>))
                {
                    SerializeList(fieldName, type, o);
                }
                //else if (fieldType.GetGenericTypeDefinition() == typeof(Dictionary<,>))
                //{
                //    ImGui.Text($"{fieldName} Dictionary");
                //}
                else
                {
                    // TODO: what to do?
                }
            }
            else if (type.IsValueType)
            {
                SerializeStruct(fieldName, type, o);
            }
            else if (type.IsClass)
            {
                // TODO: Use custom serializer, if available
                
                SerializeClass(fieldName, type, o);
            }
            else
            {
                Log.Error($"Encountered unhandled type \"{type}\" while serializing.");
            }
        }
        
        private void SerializeStruct(string fieldName, Type type, object o)
        {
            WriteField(type.ToString(), fieldName, "{");
            StartBlock();
            
            SerializeFields(type, o);

            EndBlock();
        }

        private void SerializeClass(string fieldName, Type type, object o)
        {
            (SerializationContext context, bool newContext) = GetReferenceTypeContext(o);
            
            // Only serialize the class, if it wasn't serialized before, obviously...
            if (newContext)
                context.SerializeFields(type, o);

            WriteField(type.ToString(), fieldName, context.ID.ToString());
        }

        public override string ToString()
        {
            StringBuilder finalBuilder = new();

            foreach (var context in SerializedClasses)
            {
                finalBuilder.Append($"{context.Value.ID} = {{\n");
                
                finalBuilder.Append(context.Value._builder);
                
                finalBuilder.Append("}\n\n");
            }
            
            finalBuilder.Append("Object:");

            finalBuilder.Append(_builder);

            return finalBuilder.ToString();

        }
    }

    //public static void Serialize(Entity entity, SerializationContext context)
    //{
    //    context ??= new SerializationContext();
        
    //    context.Serialize($"Entity: {entity.UUID}", typeof(Entity), entity, false);
    //}

    public static void Serialize(Entity entity, IntPtr internalContext)
    {
        SerializedObject obj = new SerializedObject(internalContext, UUID.Zero, new Dictionary<object, SerializedObject>());
        obj.Serialize(entity);
    }

    public static bool SerializeField(FieldInfo fieldInfo)
    {
        var serializeField = fieldInfo.HasCustomAttribute<SerializeFieldAttribute>();
        var dontSerializeField = fieldInfo.HasCustomAttribute<DontSerializeFieldAttribute>();
        //var hideField = fieldInfo.HasCustomAttribute<HideInEditorAttribute>();
        var showField = fieldInfo.HasCustomAttribute<ShowInEditorAttribute>();

        if (fieldInfo.IsPublic)
        {
            if (dontSerializeField)
                return false;

            return true;
        }
        
        if (serializeField)
            return true;
        
        if (showField && !dontSerializeField)
            return true;

        return false;
    }
}
