using System;
using System.IO;

namespace GlitchyEngine.Content;

interface IProcessedAssetLoader
{
	Result<Asset> Load(Stream stream);
}
