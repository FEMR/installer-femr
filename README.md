# fEMR Installers

Creates installers for the fEMR application for Mac and Windows systems.

## File Structure

- `macInstaller` contains the files for creating the Mac installer.
- `windowsInstaller` contains files for creating the Windows installer.
- `release.py` uploads all generated artifacts to S3 to release to users.

Find instructions to set up the [Mac installer](#macOS-Installer-Builder) and [Windows installer](#Windows-Installer-Builder) below.

## macOS Installer Builder

Creates a macOS installer for the fEMR application.

Acknowledgements: https://medium.com/swlh/the-easiest-way-to-build-macos-installer-for-your-application-34a11dd08744

### File Structure

- `application` contains the files that will be installed on the user's machine upon running the installer.
- `darwin/Resources` contains resources used by the installer, such as the banner image, html pages, and other required texts.
- `darwin/scripts` contains the preinstall and postinstall scripts that are used to install necessary dependencies when the installer runs.

### Creating the Installer

To compile the files into a .pkg installer:

```
./macInstaller/build-macInstaller.sh [APPLICATION_NAME] [APPLICATION_VERSION] [ARCHITECTURE]
```

Where the architecture is specified by either a 1 or 2 meaning intel or arm respectively.
For example, this is how you build an intel mac installer: ./macInstaller/build-macInstaller.sh femr 1.0.0 1

This will create the .pkg installer under the `/macInstaller/target/pkg` directory. The installer can now be double clicked inside Finder and the installer will run through the necessary steps to install the fEMR software.

### Running the Application

Once the installer has finished running through all the steps and installing the necessary software, you can now run the application. Inside your Applications folder there should now be a `fEMR` application. This can be double clicked to boot up the software.

## Windows Installer Builder

Creates a Windows installer for the fEMR application from advanced installer.

### File Structure

- `./newFemer` contatins all of the files neccessary to build the installer.
- `./femrInstall-cache` contains all the installer cache information

### Building the installer via advanced installer

To compile the installer via advanced installer, download and open advanced installer. Press the open new folder button in the top toolbar and open the folder .\installer-femr-master/windowsInstaller and open the femrInstaller2.aip file. In the advanced installer file view, delete the docker-compose .YML file, femr .ps1 file, and the Dockerfile. Re-add these three files after removing for advanced installer to correctly identify them. Your file view in advanced installer will now contain the femrInstaller2.aip , docker-compose , Dockerfile , and femr.ps1 files. Press the build button on advanced installer to build the EXE. After a successful build, press the output folder button on the same tool bar as the build button. Run the EXE located in the output folder. Once wizard has finished, run the powershell (.ps1) script in the new installation folder created by the EXE. The powershell script will open docker and run docker-compose up, you can then navigate to localhost:9000 in your preferred browser to run fEMR.

## Other Repositories

- [femr](https://github.com/FEMR/femr) - The latest version of off-chain femr
- [AWS](https://github.com/fEMR/fibula-aws) - AWS code for CI pipeline and API
- [Frontend](https://github.com/CPSECapstone/self-enrollment-frontend) - Frontend React code for self-enrollment webpage

## Uploading a release

- Installer packages are automatically released when a Github release is made in the main fEMR repo. This is done through Github Actions
  - The main repo runs a workflow dispatch to the releaser.yml workflow in this repo. From there it grabs the AWS credentials from the Github Actions secrets and uploads the installers.
  - The main script is run twice, once for intel and once for arm. Windows installer automation is not created yet.
- Running the script manually (on your machine) requires you to have the aws credentials added to your environment.

# Notes for DNS

There is a DNS server as a package in the docker compose. This DNS server is configured to redirect the femr.net to 192.168.1.2 This can be changed by editing the application/dns.conf. Details on how users can configure their routers to use the DNS can be found here: https://docs.google.com/document/d/1opcGO7SUYSOtQPjx1CUQ2PdLrzKxleHNVE4bLMBpUkE/edit?usp=sharing
