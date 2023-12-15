using GlitchyEngine.Editor;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Reflection;
using System.Text;
using GlitchyEngine.Core;
using GlitchyEngine.Extensions;
using System.Xml.Linq;

namespace GlitchyEngine.Serialization;

public static class EntitySerializer
{
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

    public static void Serialize(Entity entity, SerializationContext context)
    {
        context ??= new SerializationContext();
        
        context.Serialize($"Entity: {entity.UUID}", typeof(Entity), entity, false);
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
