using System;
using GlitchyEngine.Core;
using GlitchyEngine.Math;

namespace GlitchyEngine.Scripting;

enum ScriptFieldType
{
	case None;

	case Class;
	case Struct;

	case Entity;
	case Component;
}