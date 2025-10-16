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
YOCTO_BRANCH="scarthgap"
YOCTO_BUILD_DIR="build"
LOG_FILE="${WORK_DIR}/yocto_setup.log"

declare -Ar repos=(
    [0]="1||git://git.yoctoproject.org/poky.git|poky|${YOCTO_BRANCH}"
    [1]="1||https://github.com/openembedded/meta-openembedded.git|meta-openembedded|${YOCTO_BRANCH}"
    [2]="1||https://github.com/OE4T/meta-tegra.git|meta-tegra|${YOCTO_BRANCH}"
    [3]="1||https://github.com/OE4T/meta-tegra-community|meta-tegra-community|${YOCTO_BRANCH}"
    [4]="0||git@github.com:mihai-chiorean/meta-edgeos-jetson.git|meta-edgeos|main"
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
    for repo in ${repos[@]};
    do
        local enable=$(echo "${repo}" | cut -d'|'  -f 1)
        enable=$(eval echo "${enable}")
        [ ${enable} -ne 1 ] && {
            continue
        }

        local dest=$(echo "${repo}" | cut -d'|'  -f 2)
        dest=$(eval echo "${dest}")
        dest="$(trim "${dest}")"
        [[ -z "${dest}" ]] && {
            dest="$(pwd)"
        }

        local url=$(echo "${repo}" | cut -d'|'  -f 3)
        url=$(eval echo "${url}")

        local folder=$(echo "${repo}" | cut -d'|'  -f 4)
        folder=$(eval echo "${folder}")

        local branch=$(echo "${repo}" | cut -d'|'  -f 5)
        branch=$(eval echo "${branch}")

        if [[ ! -d "${dest}" ]]
        then
            printf "[skip] '%s'\n" "${url}"
            continue
        fi

        printf "[clone] '%s'\n" "${url}"
        mkdir -p ${dest} &&
        cd ${dest} > ${LOG_FILE} 2>&1 &&
        git clone -b "${branch}" "${url}" "${folder}" >> ${LOG_FILE} 2>&1 || {
            return 1
        }
        # git clone ${url} > ${LOG_FILE} 2>&1 &&
        # cd ${folder} > ${LOG_FILE} 2>&1 &&
        # git checkout ${branch} > ${LOG_FILE} 2>&1 || {
        #     return 1
        # }
    done
}

[[ ! -d "${PROJECT_DIR}" ]] && {
    mkdir -p "${PROJECT_DIR}"
}

cd "${PROJECT_DIR}"
if [[ ! -d "repos" ]]
then
    mkdir -p "repos"
    cd "repos"

    printf "Clone repos...\n"
    clone_repos || {
        printf "Yocto setup failed!\n"
        cd "${WORK_DIR}"
        exit 1
    }
else
    printf "Repos directory already exists!\n"
fi

cd "${PROJECT_DIR}"
if [[ ! -d "layers" ]]
then
    printf "\nPrepare the Yocto layer(s)...\n"
    mkdir -p "layers"
    cd "layers"
    ln -s ../repos/poky/meta ./meta
    ln -s ../repos/poky/meta-poky ./meta-poky
    ln -s ../repos/meta-tegra ./meta-tegra
    ln -s ../repos/meta-openembedded/meta-oe ./meta-oe
    ln -s ../repos/meta-openembedded/meta-python ./meta-python
    ln -s ../repos/meta-openembedded/meta-networking ./meta-networking
    ln -s ../repos/meta-openembedded/meta-filesystems ./meta-filesystems
    ln -s ../repos/meta-tegra-community ./meta-tegra-community
    ln -s ../repos/poky/scripts ./scripts
    ln -s "${HOME_DIR}" ./meta-edgeos
else
    printf "Layers directory already exists!\n"
fi

cd "${PROJECT_DIR}"
if [[ ! -d "${YOCTO_BUILD_DIR}" ]]
then
    printf "\nPrepare the Yocto build environment...\n"
    mkdir -p "${YOCTO_BUILD_DIR}/conf"
    cp "./layers/meta-edgeos/conf/template/bblayers.conf" "./${YOCTO_BUILD_DIR}/conf"
    cp "./layers/meta-edgeos/conf/template/local.conf" "./${YOCTO_BUILD_DIR}/conf"

    path="${PROJECT_DIR}/layers"
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
