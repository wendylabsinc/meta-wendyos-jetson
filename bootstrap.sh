#!/usr/bin/env bash

set -e          # abort on errors (nonzero exit code)
set -u          # detect unset variable usages
set -o pipefail # abort on errors within pipes
#set -x         # logs raw input, including unexpanded variables and comments

#trap "echo 'error: Script failed: see failed command above'" ERR

###
# Get absolute path in a portable way (works on Linux and macOS)
absolute_path() {
    local path="${1}"

    if [ -z "${path}" ]
    then
        return 1
    fi

    # Try different methods in order of preference
    if command -v realpath >/dev/null 2>&1
    then
        # Linux and macOS Ventura+
        realpath "${path}"
    elif command -v greadlink >/dev/null 2>&1
    then
        # GNU readlink from coreutils (brew install coreutils on macOS)
        greadlink -f "${path}"
    elif [[ "$(uname)" == "Darwin" ]] && readlink -f / >/dev/null 2>&1
    then
        # macOS Monterey 12.3+ with readlink -f support
        readlink -f "${path}"
    else
        # Fallback:
        # Use cd + pwd for absolute path resolution
        # (supported on) all POSIX systems)
        (cd -P -- "${path}" 2>/dev/null && pwd -P) || {
            echo "Error: Cannot resolve absolute path for: ${path}" >&2
            return 1
        }
    fi
}

# folder where the script is located
HOME_DIR="$(absolute_path "${0%/*}")"
# printf "HOME_DIR: %s\n" "${HOME_DIR}"

# folder from which the script was called
WORK_DIR="$(pwd)"

IMAGE_NAME="wendyos"
USER_NAME="dev"
# PROJECT_DIR="${1:-${ROOT_DIR}}"
PROJECT_DIR="${WORK_DIR}"
LOG_FILE="${WORK_DIR}/yocto_setup.log"
META_LAYER_DIR="${HOME_DIR}"
DOCKER_WORK_DIR="/home/${USER_NAME}/${IMAGE_NAME}"


YOCTO_BRANCH="scarthgap"
YOCTO_BUILD_DIR="build"

cleanup() {
    # preserve original exit code
    rc=$?
    cd -- "${WORK_DIR}" || true
    exit "${rc}"
}
trap cleanup EXIT

declare -Ar repos=(
    [0]="1|git://git.yoctoproject.org/poky.git||${YOCTO_BRANCH}"
    [1]="1|https://github.com/openembedded/meta-openembedded.git||${YOCTO_BRANCH}"
    [2]="1|https://github.com/OE4T/meta-tegra.git||${YOCTO_BRANCH}"
    [3]="1|https://github.com/OE4T/meta-tegra-community||${YOCTO_BRANCH}"
    [4]="1|git://git.yoctoproject.org/meta-virtualization.git||${YOCTO_BRANCH}"
    [5]="1|https://github.com/mendersoftware/meta-mender.git||${YOCTO_BRANCH}"
    [6]="1|https://github.com/mendersoftware/meta-mender-community.git||${YOCTO_BRANCH}"
)


##
# display help
usage() {
    cat <<EOF
  $(basename "$0") [options]

Options:

EOF
}

trim() {
    local s="$1"

    # remove leading whitespace
    s="${s#"${s%%[![:space:]]*}"}"

    # remove trailing whitespace
    s="${s%"${s##*[![:space:]]}"}"

    printf '%s' "${s}"
}

invalid_folder_structure() {
    local -r work_dir="$1"
    local -r meta_dir="$2"

    cat <<EOF >&2
ERROR: 'meta-${IMAGE_NAME}' must be located within the working directory subtree.

Current locations:
  Working directory:     ${work_dir}
  meta-${IMAGE_NAME} location:  ${meta_dir}

The bootstrap script creates a Docker container that mounts the working directory.
If 'meta-${IMAGE_NAME}' is outside this directory, it will not be accessible in the container.

Recommended actions:
  1. Clone or move meta-${IMAGE_NAME} inside the working directory
  2. Run the bootstrap script from a parent directory that contains meta-${IMAGE_NAME}

Example structure:
  /path/to/project         <- run bootstrap.sh from here
  ├── meta-${IMAGE_NAME}          <- meta layer repository
  ├── repos                <- created by bootstrap
  ├── build                <- created by bootstrap
  └── docker               <- created by bootstrap

EOF
}

###
# Check if meta layer is within the WORK_DIR subtree
validate_meta_location() {
    local work_dir
    local meta_dir

    work_dir="$(absolute_path "${WORK_DIR}")" || return 1
    meta_dir="$(absolute_path "${META_LAYER_DIR}")" || return 1

    # Check if meta layer path starts with WORK_DIR path
    case "${meta_dir}" in
        "${work_dir}"*)
            # meta layer is inside WORK_DIR subtree
            return 0
            ;;
        *)
            # meta layer is outside WORK_DIR subtree
            invalid_folder_structure "${work_dir}" "${meta_dir}"
            return 1
            ;;
    esac
}

###
function clone_repos() {
    for repo in "${repos[@]}"
    do
        local enable=$(echo "${repo}" | cut -d'|'  -f 1)
        [ "${enable}" -ne 1 ] && {
            continue
        }

        local url=$(echo "${repo}" | cut -d'|'  -f 2)
        # url=$(eval echo "${url}")

        local folder=$(echo "${repo}" | cut -d'|'  -f 3)
        # folder=$(eval echo "${folder}")
        [[ -z "${folder}" ]] && {
            folder=$(basename "${url%.git}")
        }

        local branch=$(echo "${repo}" | cut -d'|'  -f 4)
        # branch=$(eval echo "${branch}")
        [[ -z "${branch}" ]] && {
            printf "No branch for '%s'\n" "${url}"
            exit 1
        }

        [[ -d "./${folder}" ]] && {
            printf "[skip] '%s'\n" "${url}"
            continue
        }

        printf "[%s] '%s'\n" "${branch}" "${url}"
        git clone -b "${branch}" "${url}" "${folder}" >> "${LOG_FILE}" 2>&1 || {
            return 1
        }
    done
}

copy_dir() {
    local src="$1"
    local dst="$2"

    if [ -z "${src}" ] || [ -z "${dst}" ]; then
        echo "Usage: copy_dir <source_dir> <dest_dir>" >&2
        return 2
    fi

    if [ ! -d "${src}" ]; then
        echo "Source is not a directory: ${src}" >&2
        return 1
    fi

    # Ensure destination exists
    mkdir -p -- "${dst}" || return $?

    if command -v ditto >/dev/null 2>&1; then
        # Best on macOS: preserves permissions, ACLs, xattrs, symlinks
        ditto "${src}" "${dst}"
    elif command -v rsync >/dev/null 2>&1; then
        # Cross-platform: preserves perms, times, symlinks, devices, etc.
        # Trailing slashes copy contents of src into dst
        rsync -aH -- "${src}"/ "${dst}"/
    else
        # POSIX fallback (may not keep ACLs/xattrs)
        cp -Rpv -- "${src}"/. "${dst}"/
    fi
}

# Validate that meta layer is within WORK_DIR subtree
printf "Validating meta-${IMAGE_NAME} location...\n"
validate_meta_location || {
    exit 1
}

[[ ! -d "${PROJECT_DIR}" ]] && {
    mkdir -p "${PROJECT_DIR}"
}

cd "${PROJECT_DIR}"
mkdir -p "repos"
cd "repos"

printf "Clone repos...\n"
clone_repos || {
    printf "Yocto setup failed!\n"
    cd "${WORK_DIR}"
    exit 1
}

image_name=$(basename "${META_LAYER_DIR}")

printf "\nPrepare the Yocto build environment...\n"
cd "${PROJECT_DIR}"
mkdir -p "${YOCTO_BUILD_DIR}/conf"

# use the template only if the corresponding one in build/conf doesn't exist
if [[ ! -e "./${YOCTO_BUILD_DIR}/conf/bblayers.conf" ]]
then
    cp "${META_LAYER_DIR}/conf/template/bblayers.conf" "./${YOCTO_BUILD_DIR}/conf"
    sed -i.bak "s|%META-REPO%|${image_name}|g" "./${YOCTO_BUILD_DIR}/conf/bblayers.conf"
fi

if [[ ! -e "./${YOCTO_BUILD_DIR}/conf/local.conf" ]]
then
    cp "${META_LAYER_DIR}/conf/template/local.conf" "./${YOCTO_BUILD_DIR}/conf"
fi

printf "\nDirectory structure:\n"
tree -d -L 2 -I 'build|downloads|sstate-cache' || true #--charset=ascii

# prepare Docker image
printf "\nCreate docker image...\n"
docker_path="${PROJECT_DIR}/docker"
mkdir -p "${docker_path}"
copy_dir "${META_LAYER_DIR}/scripts/docker" "${docker_path}"

sed -i.bak "s|%HOST_DIR%|${PROJECT_DIR}|g" "${docker_path}/dockerfile.config"
sed -i.bak "s|%OS_NAME%|${IMAGE_NAME}|g" "${docker_path}/dockerfile.config"

cd "${PROJECT_DIR}/docker"
./docker-util.sh create

cd "${WORK_DIR}"
cat <<EOF

Run the following command(s):
   # start the docker container
   cd ./docker
   ./docker-util.sh run

   # (within container)
   cd ./${IMAGE_NAME}
   . ./repos/poky/oe-init-build-env ${YOCTO_BUILD_DIR}
   bitbake edgeos-image

EOF
