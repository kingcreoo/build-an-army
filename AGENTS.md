# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Required References

**CLAUDE.md** Provides a clear guideline for technical details & specifics when working in this repo.

**README.md** Provides a clear explanation of this game's core concept & an outline of some features. It speaks in the future tense about this game for when it is completed.

**STUDIO.md** Provides an outline of where things are located in ROBLOX studio. This is updated by the human who manages claude and this repo whenever things are changed in studio, along with a git commit.

## Code & comment conventions

- PascalCase is always used for variables and functions
- MODULES are in all caps
- Prefer writing re-usable functions over deep nesting

- Always provide a short, clear, and concise overview of a script at the first line
- Always provide a short, clear, and concise one-line summary above each function
- Always provide a short, clear, and concise one-line explanations over critical blocks in a function

## Project structure

"ReplicatedFirst" folder contains scripts that manage tasks that need to be completed immediately as the player loads in. (The only real thing here is the load screen.)

"ReplicatedStorage" folder contains scripts that are located in ReplicatedStorage that are shared between the client and server. The all important SETTINGS module is located here (at ReplicatedStorage/init.luau)

The SETTINGS module, located at /src/ReplicatedStorage/init.luau, is the primary base for any kind of data that code may need to reference. This includes but is not limited to: data that new players are to be given or data on each soldier/target type.

"ServerScriptService" folder contains all server-sided scripts. (All located in the actual ServerScriptService folder in studio.)

"StarterPlayerScripts" folder contains all client-sided scripts, including UI. (All located in the actual StarterPlayerScripts folder in studio.)

NOTES.md is a file that you are always allowed to add notes into, whether that be a temporary to-do list or a piece of logic that you want to keep long term.

## Testing approach

For testing, we use a basic tool called TestEZ that allows for testing of ROBLOX's luau. Documentation for TestEZ: https://roblox.github.io/testez/

## Roblox studio specifics

The human who manages claude (and any other AI Agent) is constantly updating the STUDIO.md file as anything is updated (as previously mentioned). This file contains a map of all parts in the workspace, replicatedstorage, and even in the startergui. When you reference a part (for example: ReplicatedStorage.Types.Soldiers.Grunt) you can check inside of STUDIO.md to see where it's located.

All remotes (RemoteEvents, RemoteFunctions, and bindables) are located in ReplicatedStorage.Remotes.

You can always request that something be added into studio WHEN IN PLAN MODE.

- Delete tasks after you are finished using them
- Always use PascalCase.
- Remember soldiers always ONLY fire at the target in their lane