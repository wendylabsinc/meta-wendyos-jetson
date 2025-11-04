#!/usr/bin/env bash

set -e          # abort on errors (nonzero exit code)
set -u          # detect unset variable usages
set -o pipefail # abort on errors within pipes
#set -x         # logs raw input, including unexpanded variables and comments

#trap "echo 'error: Script failed: see failed command above'" ERR

# folder where the script is located
HOME_DIR="$(realpath "${0%/*}")"
# printf "HOME_DIR: %s\n" "${HOME_DIR}"

# folder from which the script was called
WORK_DIR="$(pwd)"

# PROJECT_DIR="${1:-${ROOT_DIR}}"
PROJECT_DIR="${WORK_DIR}"
LOG_FILE="${WORK_DIR}/yocto_setup.log"
META_EDGEOS="${HOME_DIR}"
DOCKER_WORK_DIR="/home/dev/edgeos"


YOCTO_BRANCH="scarthgap"
YOCTO_BUILD_DIR="build"

cleanup() {
    # preserve original exit code
    rc=$?
    cd -- "${WORK_DIR}" || true
    exit "$rc"
}
trap cleanup EXIT

declare -Ar repos=(
    [0]="1|git://git.yoctoproject.org/poky.git||${YOCTO_BRANCH}"
    [1]="1|https://github.com/openembedded/meta-openembedded.git||${YOCTO_BRANCH}"
    [2]="1|https://github.com/OE4T/meta-tegra.git||${YOCTO_BRANCH}"
    [3]="1|https://github.com/OE4T/meta-tegra-community||${YOCTO_BRANCH}"
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
    local s=$1

    # remove leading whitespace
    s="${s#"${s%%[![:space:]]*}"}"

    # remove trailing whitespace
    s="${s%"${s##*[![:space:]]}"}"

    printf '%s' "$s"
}

###
function clone_repos() {
    for repo in "${repos[@]}"
    do
        local enable=$(echo "${repo}" | cut -d'|'  -f 1)
        enable=$(eval echo "${enable}")
        [ ${enable} -ne 1 ] && {
            continue
        }

        local url=$(echo "${repo}" | cut -d'|'  -f 2)
        url=$(eval echo "${url}")

        local folder=$(echo "${repo}" | cut -d'|'  -f 3)
        folder=$(eval echo "${folder}")
        [[ -z "${folder}" ]] && {
            folder=$(basename "${url%.git}")
        }

        local branch=$(echo "${repo}" | cut -d'|'  -f 4)
        branch=$(eval echo "${branch}")
        [[ -z "${branch}" ]] && {
            printf "No branch for `%s`\n" "${url}"
            exit 1
        }

        [[ -d "./${folder}" ]] && {
            printf "[skip] '%s'\n" "${url}"
            continue
        }

        printf "[%s] '%s'\n" "${branch}" "${url}"
        git clone -b "${branch}" "${url}" "${folder}" >> ${LOG_FILE} 2>&1 || {
            return 1
        }
    done
}

copy_dir() {
    local src="$1"
    local dst="$2"

    if [ -z "$src" ] || [ -z "$dst" ]; then
        echo "Usage: copy_dir <source_dir> <dest_dir>" >&2
        return 2
    fi

    if [ ! -d "$src" ]; then
        echo "Source is not a directory: $src" >&2
        return 1
    fi

    # Ensure destination exists
    mkdir -p -- "$dst" || return $?

    if command -v ditto >/dev/null 2>&1; then
        # Best on macOS: preserves permissions, ACLs, xattrs, symlinks
        ditto "$src" "$dst"
    elif command -v rsync >/dev/null 2>&1; then
        # Cross-platform: preserves perms, times, symlinks, devices, etc.
        # Trailing slashes copy contents of src into dst
        rsync -aH -- "$src"/ "$dst"/
    else
        # POSIX fallback (may not keep ACLs/xattrs)
        cp -Rpv -- "$src"/. "$dst"/
    fi
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

image_name=$(basename "${WORK_DIR}")

cd "${PROJECT_DIR}"
if [[ ! -d "${YOCTO_BUILD_DIR}" ]]
then
    printf "\nPrepare the Yocto build environment...\n"
    mkdir -p "${YOCTO_BUILD_DIR}/conf"

    cp "${META_EDGEOS}/conf/template/bblayers.conf" "./${YOCTO_BUILD_DIR}/conf"
    cp "${META_EDGEOS}/conf/template/local.conf" "./${YOCTO_BUILD_DIR}/conf"

    # tmp=$(basename "${WORK_DIR}")
    tmp="${DOCKER_WORK_DIR}/${image_name}/repos"
    sed -i.bak "s|%PATH%|${tmp}|g" "./${YOCTO_BUILD_DIR}/conf/bblayers.conf"

    tmp=$(basename "${META_EDGEOS}")
    tmp="${DOCKER_WORK_DIR}/${tmp}"
    sed -i.bak "s|%PATH_EDGEOS%|${tmp}|g" "./${YOCTO_BUILD_DIR}/conf/bblayers.conf"
else
    printf "Yocto build directory already exists!\n"
fi

printf "\nDirectory structure:\n"
tree -d -L 2 #--charset=ascii

# prepare Docker image
printf "\nCreate docker image...\n"
docker_path="${PROJECT_DIR}/../docker"
mkdir -p "${docker_path}"
copy_dir "${META_EDGEOS}/scripts/docker" "${docker_path}"

# tmp="${PROJECT_DIR}/.."
tmp="$(cd -P -- "${ROJECT_DIR}/.." && pwd -P)"
sed -i.bak "s|%EDGEOS_DIR%|${tmp}|g" "${docker_path}/dockerfile.config"

cd "${WORK_DIR}/../docker"
./docker-util.sh create

cd "${WORK_DIR}"
cat <<EOF

Run the command(s):
   # run the docker container
   cd ../docker
   ./docker-util.sh run

   # (on container)
   cd ./edgeos/${image_name}
   . ./repos/poky/oe-init-build-env ${YOCTO_BUILD_DIR}
   bitbake edgeos-image

EOF
