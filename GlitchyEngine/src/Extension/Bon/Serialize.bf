using System;

namespace Bon.Integrated
{
	extension Serialize
	{
		public static void Value<T>(BonWriter writer, StringView identifier, in T value, BonEnvironment env = gBonEnv)
		{
			writer.Identifier(identifier);
			Serialize.Value(writer, ValueView(typeof(T), &value), env);
		}

		public static void Value<T>(BonWriter writer, in T value, BonEnvironment env = gBonEnv)
		{
			Serialize.Value(writer, ValueView(typeof(T), &value), env);
		}
	}

	extension Deserialize
	{
		public static Result<void> Value<T>(BonReader reader, StringView identifier, out T value, BonEnvironment env = gBonEnv)
		{
			value = ?;

			if (Try!(reader.Identifier()) != identifier)
				return .Err;

			return Deserialize.Value(reader, ValueView(typeof(T), &value), env);
		}

		public static Result<void> Value<T>(BonReader reader, out T value, BonEnvironment env = gBonEnv)
		{
			value = ?;
			return Deserialize.Value(reader, ValueView(typeof(T), &value), env);
		}
	}
}
