
1. Clone the tegra-demo-distro repository:
$ git clone https://github.com/OE4T/tegra-demo-distro.git

2. Switch to the appropriate branch:
$ cd tegra-demo-distro
$ git checkout scarthgap

3. Initialize the git submodules:
$ git submodule update --init

4. Clone the edgeos repository:
$ cd ./layers
$ git clone git@github.com:mihai-chiorean/meta-edgeos-jetson.git

5. Source the setup-env script to create a build directory, specifying the MACHINE:
$ cd ..
$ . ./setup-env --machine jetson-orin-nano-devkit

6. Copy and modify the 'bblayers.conf.sample' and 'local.conf.sample' from
'meta-edgeos/conf/templates/edgeos' into the 'build/conf' directory.

6. Build the image:
$ bitbake edgeos-image
