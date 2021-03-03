using System;

namespace GlitchyEngine.Math
{
	/**
	 * Generates component swizzle operators for a vector.
	 */
	[AttributeUsage(.Struct | .Class)]
	struct SwizzleVectorAttribute : Attribute, IComptimeTypeApply
	{
		private int _vectorSize;

		public int VectorSize => _vectorSize;

		private String _vectorTypeName;

		this(int vectorSize, String vectorTypeName)
		{
			_vectorSize = vectorSize;
			_vectorTypeName = vectorTypeName;
		}

		/**
		 * Determines whether or not a swizzle operator can have a valid setter (e.g. no component assigned twice)
		*/
		static bool invalidSetter(int[4] cmp, int vecSize)
		{
			return cmp[0] == cmp[1] || (vecSize >= 3 && cmp[0] == cmp[2]) || (vecSize == 4 && cmp[0] == cmp[3]) ||
				(vecSize >= 3 && cmp[1] == cmp[2]) || (vecSize == 4 && cmp[1] == cmp[3]) ||
				(vecSize == 4 && cmp[2] == cmp[3]);
		}

		[Comptime]
		public void ApplyToType(Type type)
		{
			// TODO: report bug... sized array not working
			String[] componentNames = scope String[]("X", "Y", "Z", "W");

			for(int swizzleCount = 2; swizzleCount <= 4; swizzleCount++)
			{
				int[4] cmp = .();

				int cmp2max = swizzleCount > 2 ? _vectorSize : 1;
				int cmp3max = swizzleCount > 3 ? _vectorSize : 1;

				for(cmp[0] = 0; cmp[0] < _vectorSize; cmp[0]++)
				for(cmp[1] = 0; cmp[1] < _vectorSize; cmp[1]++)
				for(cmp[2] = 0; cmp[2] < cmp2max; cmp[2]++)
				for(cmp[3] = 0; cmp[3] < cmp3max; cmp[3]++)
				{
					String swizzleName = scope String(swizzleCount);
					String swizzleConstructor = scope String(swizzleCount * 3);
					String setter = scope String(128);

					bool setterInvalid = invalidSetter(cmp, swizzleCount);

					for(int c = 0; c < swizzleCount; c++)
					{
						swizzleName.Append(componentNames[cmp[c]]);

						if(c != 0)
						{
							swizzleConstructor.Append(", ");
						}
						swizzleConstructor.Append(componentNames[cmp[c]]);

						if(!setterInvalid && c < _vectorSize) //
						{
							setter.AppendF($"\n\t\t{componentNames[cmp[c]]} = value.{componentNames[c]};");
						}
					}

					//{(setterInvalid ? "[Error(\"Cannot assign multiple values to same component.\")]" : String.Empty)}		

					String swizzleString = scope $"""
						public {_vectorTypeName}{swizzleCount} {swizzleName}
						{{
							get => .({swizzleConstructor});
							set mut
							{{{setter}
							}}
						}}

						""";

					Compiler.EmitTypeBody(type, swizzleString);
				}
			}
		}
	}
}
