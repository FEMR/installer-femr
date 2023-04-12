# FEMR - Fast Electronic Medical Records

### Description 

fEMR is a fast EMR solution for remote clinics who depend on speed and ease of use rather than complex features. Check out [Team fEMR's website](https://teamfemr.org) for more information and a live demo.

# Table of Contents
1. [ Set-up/Onboarding Instructions ](#install)
2. [ Contact Us/Leave Feedback ](#contact)
3. [ Privacy Policy and EULA](#priv)

<a name="install"></a>
## Set-up/Onboarding Instructions

### Prerequsities
1. Clone our repository: ```https://github.com/CPSECapstone/installer-femr.git```
2. Download [Docker](https://www.docker.com/products/docker-desktop/).
2. For the Windows installer, download [InstallAnywhere](https://www.revenera.com/install/products/installanywhere).

### MacOS 
1. ```./macOS-x64/build-macos-x64.sh [APPLICATION_NAME] [APPLICATION_VERSION]```
2. Navigate to the `/macOS-x64/target/pkg` directory. It should now contain a .pkg installer that can be double clicked inside Finder.
3. Follow the steps on the installer to install the software.
4. Once the installer has finished running, navigate to your `Applications` folder. There should now be a `fEMR` application that can be double clicked and ran.

### Windows
1. Create a new project and set the file location as the `windowsInstaller` directory.
2. Add all of the files in `./newFemr` to the applications folder in the target computer.
3. Add the docker desktop installation to the prerequisite condition for installation. 
4. Add the cache to the project, then build the project as a single .exe file with the documents included.

<a name="contact"></a>
## Contact Us/Leave Feedback

If you find any issues with the installers or have any other feedback you'd like to give to the team, please do so [here!]()

<a name="priv"></a>
### [EULA and Privacy Policy](https://github.com/FEMR/femr/blob/master/LICENSE)
