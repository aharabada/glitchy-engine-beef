using Bon;
using System;
using Bon.Integrated;
using System.Collections;

namespace GlitchyEngine.Core
{
	[BonTarget]
	struct UUID : IHashable
	{
		[BonInclude]
		private uint64 _uuid;

		private static Random s_Random = new .() ~ delete _;

		public const UUID Zero = .(0);

		static this()
		{
			gBonEnv.typeHandlers.Add(typeof(UUID),
				((.)new => Serialize, (.)new => Deserialize));
		}

		/// Creates a new UUID with the given value.
		public this(uint64 uuid)
		{
			_uuid = uuid;
		}
		
		/// Creates a new random UUID.
		public static UUID Create()
		{
			return UUID(s_Random.NextU64());
		}

		public int GetHashCode()
		{
			return (int)_uuid;
		}

		public override void ToString(String strBuffer)
		{
			_uuid.ToString(strBuffer);
		}

		static void Serialize(BonWriter writer, ValueView val, BonEnvironment env, SerializeValueState state)
		{
			UUID uuid = *(UUID*)val.dataPtr;

			Bon.Integrated.Serialize.[Friend]Integer(typeof(uint64), writer, ValueView(typeof(uint64), &uuid._uuid));
		}

		public static Result<void> Deserialize(BonReader reader, ValueView val, BonEnvironment env, DeserializeValueState state)
		{
			Bon.Integrated.Deserialize.[Friend]Integer!(typeof(uint64), reader, val);

			return .Ok;
		}

		public static explicit operator uint64(UUID id)
		{
			return id._uuid;
		}
	}
}