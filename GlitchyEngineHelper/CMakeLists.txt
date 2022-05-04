# CMakeList.txt : CMake project for GlitchyEngineHelper, include source and define
# project specific logic here.
#
cmake_minimum_required (VERSION 3.15)

project ("GlitchyEngineHelper")

# Add source to this project's executable.
add_library (GlitchyEngineHelper "GlitchyEngineHelper.cpp" "GlitchyEngineHelper.h" "vendor/xxHash/xxhash.c" "vendor/xxHash/xxhash.h" "vendor/DirectXTK/Src/DDSTextureLoader.cpp")

include_directories("vendor/DirectXTK/Inc")

# Use statically linked multithreaded MSVC runtime
set_property(TARGET GlitchyEngineHelper PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
