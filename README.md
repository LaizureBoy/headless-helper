**THIS SCRIPT IS INTENDED TO BE RAN ON THE COMPUTER YOU WANT TO USE THE HEADLESS HOST ON.**   

What does this script do exactly?
- Downloads the latest release of the headless client mod and installs it into the root directory.
- Checks for mods that are incompatible with FIKA and asks you to remove them, list is taken from the FIKA discord.
- Asks your hosting method and changes the IP address sections of fika.jsonc and the headless start script.
- Asks to forward the ports necessary for incoming connections so that FIKA can communicate with the client. (FIKA Utils can also do this)
- Copies the headless start script to the root SPT directory for easy launching.
  
Make sure to place this script in your root SPT directory!

This is a powershell script to help you install and configure the headless client for the FIKA mod. 
To use it, double click the .ps1 file downloaded from here or right click > open with Powershell. 

If you have any issues or errors, feel free to add them to the issues here.
