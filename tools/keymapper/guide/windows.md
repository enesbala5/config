Clone repo to C:/dotenv

Install Keymapper
<!-- --- -->
winget install keymapper

Create symlink for keymapper
<!-- --- -->
New-Item -Path ~/keymapper.conf -ItemType SymbolicLink -Value C:\dotenv\keymapper\configuration.conf