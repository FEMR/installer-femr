Write-Host "

 .d888 8888888888 888b     d888 8888888b.  
d88P""  888        8888b   d8888 888   Y88b 
888    888        88888b.d88888 888    888 
888888 8888888    888Y88888P888 888   d88P 
888    888        888 Y888P 888 8888888P""  
888    888        888  Y8P  888 888 T88b   
888    888        888   ""   888 888  T88b  
888    8888888888 888       888 888   T88b 
   
"

Write-Host "Starting fEMR... This might take a second"
Write-Host "Ctrol+C in this window to shutdown the fEMR server"

Start-Process "C:\ProgramData\Microsoft\Windows\Start Menu\Docker Desktop"
Start-Sleep -Seconds 15
docker-compose up