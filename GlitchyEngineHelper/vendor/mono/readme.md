# Why mono?
Eventhough mono only supports up to donet Framework 4.8 while other options support all the latest features. As of now only mono supports reloading assemblies.

# Building Mono:
1. Clone the mono repository: `git clone --recursive https://github.com/mono/mono`
2. Build Mono:
   - For Windows:
      1. Open the solution `msvc/mono.sln`
      2. Build the entire Solution (Debug and Release)
      3. Binary output will be in `msvc\build\sgen\x64\lib\` (Debug and Release)
      4. Include files will be in `msvc\include`
