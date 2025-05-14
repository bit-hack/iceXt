cmake_minimum_required(VERSION 3.0)
project(iceXtEmu)

add_compile_definitions(_CRT_SECURE_NO_WARNINGS)

add_executable(iceXtEmu
  src/cpu.c
  src/cpu.h
  src/font.c
  src/main.c
  src/disk.c
  src/disk.h
  src/display.c
  src/display.h
  src/serial.c
  src/serial.h
)

add_subdirectory(src/udis86)

set(SDL_LIBRARY     "unknown" CACHE FILEPATH "SDL1.2 library path")
set(SDL_INCLUDE_DIR "unknown" CACHE PATH     "SDL1.2 include directory")

include_directories(iceXtEmu ${SDL_INCLUDE_DIR} src)
target_link_libraries(iceXtEmu ${SDL_LIBRARY} lib_udis86)
