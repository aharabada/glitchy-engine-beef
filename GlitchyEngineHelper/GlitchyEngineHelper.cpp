// GlitchyEngineHelper.cpp : Defines the entry point for the application.
//

#include "GlitchyEngineHelper.h"

using namespace std;

GE_EXPORT int GE_CALLTYPE test(int x, int y)
{
	return x + y;
}

GE_EXPORT XXH64_hash_t bla(void* buffer, size_t size, XXH64_hash_t seed)
{
	return XXH64(buffer, size, seed);
}
