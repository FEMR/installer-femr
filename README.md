# fEMR Installers

Creates installers for the fEMR application for Mac and Windows systems.

## File Structure

- `macOS-x64` contains the files for creating the Mac installer.
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
./macOS-x64/build-macos-x64.sh [APPLICATION_NAME] [APPLICATION_VERSION] [ARCHITECTURE]
```

Where the architecture is specified by either a 1 or 2 meaning intel or arm respectively.
For example, this is how you build an intel mac installer: ./macOS-x64/build-macos-x64.sh femr 1.0.0 1

This will create the .pkg installer under the `/macOS-x64/target/pkg` directory. The installer can now be double clicked inside Finder and the installer will run through the necessary steps to install the fEMR software.

### Running the Application

Once the installer has finished running through all the steps and installing the necessary software, you can now run the application. Inside your Applications folder there should now be a `fEMR` application. This can be double clicked to boot up the software.

## Windows Installer Builder

Creates a Windows installer for the fEMR application from advanced installer.

### File Structure

- `./newFemer` contatins all of the files neccessary to build the installer.
- `./femrInstall-cache` contains all the installer cache information

### Building the installer via advanced installer

To compile the installer via advanced installer, create a new project with the file location as the windowsInstaller file location. Add all of the files in ./newFemr to the applications folder in the target computer. Add the docker desktop installation to the prerequisite condition for instillation. Add the cache to the project then build the project as a single exe file with the documents included.

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
