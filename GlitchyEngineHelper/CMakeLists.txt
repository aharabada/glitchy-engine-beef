# CMakeList.txt : CMake project for GlitchyEngineHelper, include source and define
# project specific logic here.
#
cmake_minimum_required (VERSION 3.15)

project ("GlitchyEngineHelper")

# Nethost:

# Directory where the files for hosting a dotnet enviroment are located
SET(DOTNET_HOST_DIR "vendor/dotnethost")

# todo: Find out how to handle this on other platforms
# target_link_libraries(GlitchyEngineHelper "vendor/dotnethost/nethost.lib")

add_library(NetHost OBJECT IMPORTED)
set_target_properties(NetHost PROPERTIES IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/vendor/dotnethost/nethost.lib)
set_property(TARGET NetHost PROPERTY IMPORTED_OBJECTS ${CMAKE_SOURCE_DIR}/vendor/dotnethost/nethost.lib)

# Copy nethost.dll to output directory
configure_file("${DOTNET_HOST_DIR}/nethost.dll" "${CMAKE_CURRENT_BINARY_DIR}/nethost.dll" COPYONLY)

#  GlitchyEngineHelper:

# Add source to this project's executable.
add_library (GlitchyEngineHelper STATIC
	"GlitchyEngineHelper.cpp" "GlitchyEngineHelper.h" "vendor/xxHash/xxhash.c" "vendor/xxHash/xxhash.h" "vendor/DirectXTK/Src/DDSTextureLoader.cpp" "DotNetRuntime.h" "DotNetRuntime.cpp"
	# Link object files from nethost into library (kinda dirty I think, but avoids linking to nethost.lib when compiling in beef)
	$<TARGET_OBJECTS:NetHost>
)

target_include_directories(GlitchyEngineHelper PRIVATE
	"vendor/DirectXTK/Inc"
	${DOTNET_HOST_DIR}
)

IF (WIN32)
	add_compile_definitions(WINDOWS)
ENDIF()

# Use statically linked multithreaded MSVC runtime
set_property(TARGET GlitchyEngineHelper PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")