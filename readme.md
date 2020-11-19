# ABC Reader
This will import Lithtech ABC files and allow Godot to read them as scenes. 

## Supported Formats

This plugin currently supports ABC versions:
- Version 6
- Version 9
- Version 10
- Version 11
- Version 12
- Version 13

While the plugin loads animations for every version, it's currently only working for version 6 models. In addition, vertex animations are loaded for version 6 models, but are currently not implemented. 

## Usage

The editor plugin included will allow you to import ABC files directly into your project. You can also use `ModelBuilder.gd`'s `build` function to import scenes at runtime.

If an unsupported ABC is loaded, an error message will be printed to your console. Feel free to open a ticket with a sample ABC so I can debug the issue when I find the time.

## Installation

Simply drop this into `<GodotProject>/Addons/ABCReader` and enable it from the plugins setting panel.