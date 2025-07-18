**THIS SCRIPT IS INTENDED TO BE RAN ON THE COMPUTER YOU WANT TO USE THE HEADLESS HOST ON. MAKE A NEW FOLDER AND PUT THIS SCRIPT IN IT**   

What does this script do exactly?
- Explains the difference between the server, client, and headless client.
- Asks you to select your FIKA installation folder
- Edits the fika.jsonc file to generate a new profile on server launch if no headless profiles are found, then retries.
- Copies contents of the selected folder to the script folder's directory.
- Downloads the latest release of the headless client mod and installs it into the root directory.
- Checks for mods that are incompatible with FIKA and asks you to remove them, list is taken from the FIKA discord.

Planned 
- Ask how the user is going to host the server and help them configure it automatically before copying the files.
- Adjust and copy the headless start script for the server.
  
Make sure to place this script in your root SPT directory!

This is a powershell script to help you install and configure the headless client for the FIKA mod. Place it inside a new folder that you want to be the headless folder.
To use it, double click the .ps1 file downloaded from here or right click > open with Powershell. 
Afterwards, copy the new headless folder to the computer you want to run as a headless client.
If you have any issues or errors, feel free to add them to the issues here.
