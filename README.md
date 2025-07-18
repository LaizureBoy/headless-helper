# **THIS SCRIPT IS INTENDED TO BE RAN ON THE COMPUTER YOU INITIALLY SET UP FIKA WITH!**   

Note: This script was put together mostly by ChatGPT o4-mini-high, with slight adjustments made by me to fix bugs and improve legibility. If that concerns you, I understand and you absolutely don't have to run this! The instructions are pretty easy to follow on the fika-gitbook.

## What does this script do exactly?
- Explains the difference between the server, client, and headless client.
- Asks you to select your FIKA installation folder
- Edits the fika.jsonc file to generate a new profile on server launch if no headless profiles are found, then retries.
- Asks if you'd like to name your new headless client profile
- Asks if you're going to use the headless folder on the PC the script is ran on, or a remote computer, and then prompts you on how to do so. 
- Copies contents of the selected folder to the script folder's directory.
- Downloads the latest release of the headless client mod and installs it into the root directory.
- Checks for mods that are incompatible with FIKA and asks you to remove them, list is taken from the FIKA discord.

**Planned**
- Improve legibility and better explain some steps.

  
Make sure to place this script in your root SPT directory!

## Installation: 
Place this script inside a new folder that you want to be the headless folder.
To use it, double click the .ps1 file downloaded from here or right click > open with Powershell. 
Afterwards, copy the new headless folder to the computer you want to run as a headless client.  

If you have any issues or errors, feel free to add them to the issues here or check out the [Fika discord.](https://discord.gg/project-fika)
