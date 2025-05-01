cmake_minimum_required(VERSION 3.0)
project(iceXtEmu)

add_compile_definitions(_CRT_SECURE_NO_WARNINGS)

add_executable(iceXtEmu
  src/cpu.c
  src/cpu.h
  src/main.c
)
