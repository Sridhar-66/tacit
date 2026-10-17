# Graphis's one-step edits and comment marks as a QML module (Tacit.Edit). build.sh builds and installs it.
cmake_minimum_required(VERSION 3.21)
project(tacitedit LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Quick)
find_package(KF6SyntaxHighlighting REQUIRED)
qt_standard_project_setup(REQUIRES 6.8)
qt_add_qml_module(tacitedit
    URI Tacit.Edit
    VERSION 1.0
    PLUGIN_TARGET tacitedit
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml/Tacit/Edit
    SOURCES editblock.h editblock.cpp
)
target_link_libraries(tacitedit PRIVATE Qt6::Quick KF6::SyntaxHighlighting)
