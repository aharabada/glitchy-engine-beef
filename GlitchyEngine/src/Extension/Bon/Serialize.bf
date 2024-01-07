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

		public static bool IsBool(BonReader reader, BonEnvironment env = gBonEnv)
		{
			return reader.inStr.StartsWith(bool.TrueString, StringComparison.OrdinalIgnoreCase) || reader.inStr.StartsWith(bool.FalseString, StringComparison.OrdinalIgnoreCase);
		}

		public enum NumberType
		{
			None,
			Integer,
			Float,
			Double,
			Decimal
		}

		/*public static bool IsNumber(BonReader reader, out NumberType numberType)
		{
			numberType = .None;

			StringView tmpView = reader.inStr;

			if (tmpView.StartsWith('-') || tmpView.StartsWith('+'))
				tmpView.RemoveFromStart(1);

			if (tmpView.StartsWith('NaN', StringComparison.OrdinalIgnoreCase) || tmpView.StartsWith('infinity', StringComparison.OrdinalIgnoreCase))
			{
				numberType = .Double;
				return true;
			}

			bool isNumber = false;

			while (true)
			{
				if (tmpView[0].IsNumber)
				{
					isNumber = true;
					tmpView.RemoveFromStart(1);
				}
				else if (tmpView.StartsWith('.'))
				{
					// We also don't allow floats like .5f
					if (!isNumber)
						return false;

					tmpView.RemoveFromStart(1);

					// Err on the side of caution and assume double for precision
					numberType = .Double;
				}
			}
			
			
			if (tmpView.StartsWith('f'))
				numberType = .Float;
			else if (tmpView.StartsWith('m'))
				numberType = .Decimal;
			else if (numberType != .Double)
				numberType = .Integer;

			return isNumber;
		}*/
	}
}
