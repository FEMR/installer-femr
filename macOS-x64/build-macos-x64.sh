#!/bin/bash

#Configuration Variables and Parameters

#Parameters
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
TARGET_DIRECTORY="$SCRIPTPATH/target"
PRODUCT=${1}
VERSION=${2}
ARCH=${3}
DATE=`date +%Y-%m-%d`
TIME=`date +%H:%M:%S`
LOG_PREFIX="[$DATE $TIME]"
SQL_CONTAINER="docker.io/library/mysql:9.1.0"
FEMR_CONTAINER="teamfemrdev/teamfemr:latest"
DNS_CONTAINER="strm/dnsmasq:latest"

function printSignature() {
  cat "$SCRIPTPATH/utils/ascii_art.txt"
  echo
}

function printUsage() {
  echo -e "\033[1mUsage:\033[0m"
  echo "$0 [APPLICATION_NAME] [APPLICATION_VERSION] [ARCHITECTURE]"
  echo
  echo -e "\033[1mOptions:\033[0m"
  echo "  -h (--help)"
  echo
  echo -e "\033[1mExample:\033[0m"
  echo "$0 femr 2.6.0 1"

}

#Start the generator
printSignature

#Argument validation
if [[ "$1" == "-h" ||  "$1" == "--help" ]]; then
    printUsage
    exit 1
fi
if [ -z "$1" ]; then
    echo "Please enter a valid application name for your application"
    echo
    printUsage
    exit 1
else
    echo "Application Name : $1"
fi
if [[ "$2" =~ [0-9]+.[0-9]+.[0-9]+ ]]; then
    echo "Application Version : $2"
else
    echo "Please enter a valid version for your application (format [0-9].[0-9].[0-9])"
    echo
    printUsage
    exit 1
fi
if [[ ! "$3" =~ ^[12]$ ]]; then
    echo "Please enter a valid MacOS architecture (1: Intel, 2: Arm)"
    echo
    printUsage
    exit 1
else
    if [[ "$3" == "1" ]]; then
        echo "MacOS Architecture : Intel"
    else
        echo "MacOS Architecture : Apple Silicon"
    fi
fi

#Functions
go_to_dir() {
    pushd $1 >/dev/null 2>&1
}

log_info() {
    echo "${LOG_PREFIX}[INFO]" $1
}

log_warn() {
    echo "${LOG_PREFIX}[WARN]" $1
}

log_error() {
    echo "${LOG_PREFIX}[ERROR]" $1
}

deleteInstallationDirectory() {
    log_info "Cleaning $TARGET_DIRECTORY directory."
    rm -rf "$TARGET_DIRECTORY"

    if [[ $? != 0 ]]; then
        log_error "Failed to clean $TARGET_DIRECTORY directory" $?
        exit 1
    fi
}

createInstallationDirectory() {
    if [ -d "${TARGET_DIRECTORY}" ]; then
        deleteInstallationDirectory
    fi
    mkdir -pv "$TARGET_DIRECTORY"

    if [[ $? != 0 ]]; then
        log_error "Failed to create $TARGET_DIRECTORY directory" $?
        exit 1
    fi
}

pull_and_save_docker_images() {
    log_info "Pulling docker images... If this fails, make sure Docker is running."
    docker pull $SQL_CONTAINER
    docker pull $FEMR_CONTAINER
    docker pull $DNS_CONTAINER
    log_info "Saving docker images..."
    docker save $SQL_CONTAINER > ${TARGET_DIRECTORY}"/darwinpkg/Library/${PRODUCT}/${VERSION}/mysql:9.1.0.tar"
    docker save $FEMR_CONTAINER > ${TARGET_DIRECTORY}"/darwinpkg/Library/${PRODUCT}/${VERSION}/femr.tar"
    docker save $DNS_CONTAINER > ${TARGET_DIRECTORY}"/darwinpkg/Library/${PRODUCT}/${VERSION}/dnsmasq.tar"
    log_info "Completed moving docker images"
}

copyDarwinDirectory(){
  createInstallationDirectory
  cp -r "$SCRIPTPATH/darwin" "${TARGET_DIRECTORY}/"
  chmod -R 755 "${TARGET_DIRECTORY}/darwin/scripts"
  chmod -R 755 "${TARGET_DIRECTORY}/darwin/Resources"
  chmod 755 "${TARGET_DIRECTORY}/darwin/Distribution"
}

copyBuildDirectory() {
    sed -i -e 's#__VERSION__#'${VERSION}'#g' "${TARGET_DIRECTORY}/darwin/scripts/postinstall"
    sed -i -e 's#__PRODUCT__#'${PRODUCT}'#g' "${TARGET_DIRECTORY}/darwin/scripts/postinstall"
    chmod -R 755 "${TARGET_DIRECTORY}/darwin/scripts/postinstall"

    sed -i -e 's#__VERSION__#'${VERSION}'#g' "${TARGET_DIRECTORY}/darwin/scripts/preinstall"
    sed -i -e 's#__PRODUCT__#'${PRODUCT}'#g' "${TARGET_DIRECTORY}/darwin/scripts/preinstall"
    chmod -R 755 "${TARGET_DIRECTORY}/darwin/scripts/preinstall"

    sed -i -e 's#__VERSION__#'${VERSION}'#g' "${TARGET_DIRECTORY}/darwin/Distribution"
    sed -i -e 's#__PRODUCT__#'${PRODUCT}'#g' "${TARGET_DIRECTORY}/darwin/Distribution"
    sed -i -e 's#__SCRIPTPATH__#'${SCRIPTPATH}'#g' "${TARGET_DIRECTORY}/darwin/Distribution"

    sed -i -e 's/__VERSION__/'${VERSION}'/g' "${TARGET_DIRECTORY}/darwin/scripts/preinstall"
    sed -i -e 's/__PRODUCT__/'${PRODUCT}'/g' "${TARGET_DIRECTORY}/darwin/scripts/preinstall"
    chmod -R 755 "${TARGET_DIRECTORY}/darwin/scripts/preinstall"

    chmod -R 755 "${TARGET_DIRECTORY}/darwin/Distribution"

    sed -i -e 's/__VERSION__/'${VERSION}'/g' "${TARGET_DIRECTORY}"/darwin/Resources/*.html
    sed -i -e 's/__PRODUCT__/'${PRODUCT}'/g' "${TARGET_DIRECTORY}"/darwin/Resources/*.html
    chmod -R 755 "${TARGET_DIRECTORY}/darwin/Resources/"

    rm -rf "${TARGET_DIRECTORY}/darwinpkg"
    mkdir -p "${TARGET_DIRECTORY}/darwinpkg"

    #Copy cellery product to /Library/Cellery
    mkdir -p "${TARGET_DIRECTORY}"/darwinpkg/Library/${PRODUCT}/${VERSION}
    cp -a "$SCRIPTPATH"/application/. "${TARGET_DIRECTORY}"/darwinpkg/Library/${PRODUCT}/${VERSION}
    chmod -R 755 "${TARGET_DIRECTORY}"/darwinpkg/Library/${PRODUCT}/${VERSION}

    # If Intel (1), replace docker-compose.yml with Intel-specific version
    if [[ "${ARCH}" == "1" ]]; then
        rm -f "${TARGET_DIRECTORY}/darwinpkg/Library/${PRODUCT}/${VERSION}/docker-compose.yml"
        cp "$SCRIPTPATH/docker-compose-intel.yml" "${TARGET_DIRECTORY}/darwinpkg/Library/${PRODUCT}/${VERSION}/docker-compose.yml"
    fi

    #Sets the script_dir variable that's located in the postinstall script.
    sed -i -e 's#__SCRIPT_DIR__#''/var/'${PRODUCT}'#g' "${TARGET_DIRECTORY}/darwinpkg/Library/${PRODUCT}/${VERSION}/start-femr"

    rm -rf "${TARGET_DIRECTORY}/package"
    mkdir -p "${TARGET_DIRECTORY}/package"
    chmod -R 755 "${TARGET_DIRECTORY}/package"

    rm -rf "${TARGET_DIRECTORY}/pkg"
    mkdir -p "${TARGET_DIRECTORY}/pkg"
    chmod -R 755 "${TARGET_DIRECTORY}/pkg"
}

function buildPackage() {
    log_info "Application installer package building started.(1/3)"
    pkgbuild --identifier "org.${PRODUCT}.${VERSION}" \
    --version "${VERSION}" \
    --scripts "${TARGET_DIRECTORY}/darwin/scripts" \
    --root "${TARGET_DIRECTORY}/darwinpkg" \
    "${TARGET_DIRECTORY}/package/${PRODUCT}.pkg" > /dev/null 2>&1
}

function buildProduct() {
    log_info "Application installer product building started.(2/3)"
    productbuild --distribution "${TARGET_DIRECTORY}/darwin/Distribution" \
    --resources "${TARGET_DIRECTORY}/darwin/Resources" \
    --package-path "${TARGET_DIRECTORY}/package" \
    "${TARGET_DIRECTORY}/pkg/$1" > /dev/null 2>&1
}

function signProduct() {
    log_info "Application installer signing process started.(3/3)"
    mkdir -pv "${TARGET_DIRECTORY}/pkg-signed"
    chmod -R 755 "${TARGET_DIRECTORY}/pkg-signed"

    read -p "Please enter the Apple Developer Installer Certificate ID:" APPLE_DEVELOPER_CERTIFICATE_ID
    productsign --sign "Developer ID Installer: ${APPLE_DEVELOPER_CERTIFICATE_ID}" \
    "${TARGET_DIRECTORY}/pkg/$1" \
    "${TARGET_DIRECTORY}/pkg-signed/$1"

    pkgutil --check-signature "${TARGET_DIRECTORY}/pkg-signed/$1"
}

function createInstaller() {
    log_info "Application installer generation process started.(3 Steps)"
    buildPackage
    # If Intel, name differently
    if [ "$ARCH" == "1" ]; then
        ARCH_NAME="intel"
    elif [ "$ARCH" == "2" ]; then
        ARCH_NAME="arm"
    else
        echo "Unknown ARCH: $ARCH"
        ARCH_NAME=""
    fi
    buildProduct ${PRODUCT}-macos-installer-${ARCH_NAME}-${VERSION}.pkg
    while true; do
        read -p "Do you wish to sign the installer (You should have Apple Developer Certificate) [y/N]?" answer
        [[ $answer == "y" || $answer == "Y" ]] && FLAG=true && break
        [[ $answer == "n" || $answer == "N" || $answer == "" ]] && log_info "Skipped signing process." && FLAG=false && break
        echo "Please answer with 'y' or 'n'"
    done
    [[ $FLAG == "true" ]] && signProduct ${PRODUCT}-macos-installer-x64-${VERSION}.pkg
    log_info "Application installer generation steps finished."
}

function createUninstaller(){
    cp "$SCRIPTPATH/darwin/Resources/uninstall.sh" "${TARGET_DIRECTORY}/darwinpkg/Library/${PRODUCT}/${VERSION}"
    sed -i -e "s/__VERSION__/${VERSION}/g" "${TARGET_DIRECTORY}/darwinpkg/Library/${PRODUCT}/${VERSION}/uninstall.sh"
    sed -i -e "s/__PRODUCT__/${PRODUCT}/g" "${TARGET_DIRECTORY}/darwinpkg/Library/${PRODUCT}/${VERSION}/uninstall.sh"
}

#Pre-requisites
command -v mvn -v >/dev/null 2>&1 || {
    log_warn "Apache Maven was not found. Please install Maven first."
    # exit 1
}
command -v ballerina >/dev/null 2>&1 || {
    log_warn "Ballerina was not found. Please install ballerina first."
    # exit 1
}

#Main script
log_info "Installer generating process started."

copyDarwinDirectory
copyBuildDirectory
pull_and_save_docker_images
createUninstaller
createInstaller

log_info "Installer generating process finished"
exit 0
