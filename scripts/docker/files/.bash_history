git cat-file tag <name>
git log -1 --format=%ai <tagname>
git apply --reject <path-to-patch>
devtool modify virtual/kernel
bitbake virtual/kernel
bitbake virtual/kernel-c devshell
lsdiff <patch>
git am --3way [--signoff] [--include=<path>/**] [--exclude=<path>/**] <patch>
git show --name-only <sha>
git format-patch -1 <sha>
git show --name-only <sha>
git log --grep '<subject-line>'
git am --3way --include=<path>/** <path>/recipes-
git fetch upstream [--unshallow] --tags
git checkout [tag|branch]
git rev-parse --is-shallow-repository
git diff --stat <old> <new>
git diff <old> <new> > <patch>
git branch -f <branch> HEAD
oe-pkgdata-util list-pkgs | grep <recipe-name>
oe-pkgdata-util list-pkg-files <image> | grep e2fsprogs
oe-pkgdata-util lookup-recipe util-linux-fdisk
bitbake-layers show-recipes virtual/kernel
bitbake-layers show-appends
bitbake-layers show-layers
bitbake virtual/kernel -c menuconfig
bitbake virtual/kernel -c diffconfig
bitbake virtual/kernel -c savedefconfig
