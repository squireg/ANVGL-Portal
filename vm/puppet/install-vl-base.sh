#!/bin/bash
# Install base environment for a VL job image
#
# Content taken from installPuppet-{centos,debian}.sh and the vl_provisioning.sh
# template.
#
usage() {
    echo "Usage: $0 [-r <git_url>] [-b <git_branch>]"
    echo ""
    echo "  git_url - The git repository URL to fetch  puppet modules from."
    echo "  git_branch - Branch in the git repository to fetch modules from (default master)"
    exit 1
}

# Gather any arguments
while getopts "b:r:h" o; do
    case "$o" in
        b)
            branch=$OPTARG
            ;;
        h)
            usage
            ;;
        r)
            baseUrl=$OPTARG
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# /////////////////////////////
# Default arguments if not specified on the command line.
#
# Edit these variables if you need to download from a different git
# repo/branch.
#
# /////////////////////////////

# baseUrl -- git repository url
if [ -z "$baseUrl" ]; then
    baseUrl="https://github.com/AuScope/ANVGL-Portal.git"
fi

# branch -- branch in the git repo
if [ -z "$branch" ]; then
    branch="master"
fi

# pathSuffix -- path to puppet modules in the repo
pathSuffix="/vm/puppet/modules/"

# temporary directory for modules
tmpModulesDir="/tmp/anvgl/modules"

# Directory of puppet modules where vl modules will be installed
moduleDir="/etc/puppet/modules"

# Install puppet itself if not already available
if hash puppet 2>/dev/null; then
    echo "Puppet version $(puppet --version ) already installed."
    if [ -f /etc/debian_version ]; then
        apt-get update
    else
        rpm -ivh http://yum.puppetlabs.com/el/6/products/x86_64/puppetlabs-release-6-7.noarch.rpm
    fi
else
    # Determine what OS we're using so we install appropriately
    # Checks for a debian based system, or assumes rpm based
    if [ -f /etc/debian_version ]; then
        apt-get update
        apt-get install -y puppet
    else
        rpm -ivh http://yum.puppetlabs.com/el/6/products/x86_64/puppetlabs-release-6-7.noarch.rpm
        yum install -y puppet
    fi
fi

#sudo sh -c 'echo "    server = master.local" >> /etc/puppet/puppet.conf'
#sudo service puppet restart
#sudo chkconfig puppet on

#/////////////////////////////
#Install Additional Modules
#/////////////////////////////
# Puppet simply reports already installed modules, so this is safe
# Puppet Forge Modules
puppet module install stahnma/epel
if [ $? -ne 0 ]
then
    echo "Failed to install puppet module stahnma/epel"
    exit 1
fi

puppet module install example42/puppi
if [ $? -ne 0 ]
then
    echo "Failed to install puppet module example42/puppi"
    exit 1
fi

puppet module install jhoblitt/autofsck
if [ $? -ne 0 ]
then
    echo "Failed to install puppet module jhoblitt/autofsck"
    exit 1
fi

puppet module install puppetlabs/stdlib
if [ $? -ne 0 ]
then
    echo "Failed to install puppet module puppetlabs/stdlib"
    exit 1
fi

#/////////////////////////////
# Clone specified git repository into $tmpModulesDir and install puppet modules.
#
# First checks whether the vl modules are already available.
#/////////////////////////////

if [ ! -d "$moduleDir/vl_base" ]; then
    echo "Installing vl base modules into $moduleDir/vl_base"
    if [ -f /etc/debian_version ]; then
        apt-get install -y git
    else
        yum install -y git
    fi

    # Assumes our temp dir does not already have content!
    #Ensure suffix doesn't start with a '/'
    if [ `head -c 2 <<< "$pathSuffix"` != "/" ]
    then
        pathSuffix=`tail -c +2 <<< "$pathSuffix"`
    fi

    # Clone the git repository into $tmpModulesDir so we can extract the
    # puppet modules.  Make sure to use the correct branch!
    mkdir -p "$tmpModulesDir"
    git clone --branch "$branch" --single-branch --depth 1 "$baseUrl" "$tmpModulesDir"

    #Now copy the modules to the puppet module install directory
    find "$tmpModulesDir/$pathSuffix" -maxdepth 1 -mindepth 1 -type d -exec cp {} -r "$moduleDir" \;
    if [ $? -ne 0 ]
    then
        echo "Failed copying to puppet module directory - aborting"
        exit 2
    fi

    # Tidy up
    rm -rf "$tmpModulesDir"
else
    echo "Common vl modules found in $moduleDir/vl_base"
fi

# //////////////////////////////
# Provision VL base environment
# //////////////////////////////

# cd back out of the deleted directory to avoid issues with puppet application
cd; cd -

# Apply puppet modules
puppet apply <<EOF
include vl_base
EOF
