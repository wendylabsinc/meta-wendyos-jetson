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

YOCTO_BRANCH="scarthgap"
YOCTO_BUILD_DIR="build"

EDGEOS_URL="git@github.com:mihai-chiorean/meta-edgeos-jetson.git"
EDGEOS_BRANCH="${EDGEOS_BRANCH:-}"


[[ -z "${EDGEOS_BRANCH}" ]] && {
    prog="$(basename $0)"
    printf "meta-edgeos branch must be provided!\n"
    printf "Run:\n"
    printf "   EDGEOS_BRANCH=<branch> <path>/${prog}\n"
    exit 1
}

declare -Ar repos=(
    [0]="1|git://git.yoctoproject.org/poky.git||${YOCTO_BRANCH}"
    [1]="1|https://github.com/openembedded/meta-openembedded.git||${YOCTO_BRANCH}"
    [2]="1|https://github.com/OE4T/meta-tegra.git||${YOCTO_BRANCH}"
    [3]="1|https://github.com/OE4T/meta-tegra-community||${YOCTO_BRANCH}"
    [5]="1|https://github.com/mendersoftware/meta-mender.git||${YOCTO_BRANCH}"
    [6]="1|https://github.com/mendersoftware/meta-mender-community.git||${YOCTO_BRANCH}"
    [4]="1|${EDGEOS_URL}|meta-edgeos|${EDGEOS_BRANCH}"
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

cd "${PROJECT_DIR}"
if [[ ! -d "${YOCTO_BUILD_DIR}" ]]
then
    printf "\nPrepare the Yocto build environment...\n"
    mkdir -p "${YOCTO_BUILD_DIR}/conf"

    path="${PROJECT_DIR}/repos"
    cp "${path}/meta-edgeos/conf/template/bblayers.conf" "./${YOCTO_BUILD_DIR}/conf"
    cp "${path}/meta-edgeos/conf/template/local.conf" "./${YOCTO_BUILD_DIR}/conf"

    sed -i.bak "s|%PATH%|${path}|g" "./${YOCTO_BUILD_DIR}/conf/bblayers.conf"
else
    printf "Yocto build directory already exists!\n"
fi

printf "\nDirectory structure:\n"
tree -d -L 2 #--charset=ascii

    cat <<EOF

Run the command(s):
   . ./repos/poky/oe-init-build-env ${YOCTO_BUILD_DIR}
   bitbake edgeos-image

EOF
