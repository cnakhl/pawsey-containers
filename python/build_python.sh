#!/bin/bash


### BEGIN OF EDITABLE: edit these variables to change which images are being built
# Define versions of interest
py_ver="3.9"
ipy_ver="2020.2"
cuda_ver="10.2" # this is for cuda-hpc-python -- BEWARE that for EACH cuda version you need to write a SPECIFIC Dockerfile
cuda_toolkit_ver="10.2.89" # this is for cuda-intel-hpc-python
mpich_ver="3.4.3"
hdf5_ver="1.12.1"
# Decide whether you want to enable interaction with Git remote ("0" is disabled)
git_enabled="1"
# Git remote to push updated versioned requirements files
git_remote="origin"
### END OF EDITABLE


# SHOULD NOT modify past this point


echo " ***** "
echo " This is an experimental script to automate build of some Pawsey base images."
echo " Please ensure you are logged in to the container registry, otherwise push commands will fail."
echo " Please also ensure you have the GitHub credentials to commit and push changes to this remote project."
echo " ***** "
echo ""


# Define work directory for this script
basedir=$(readlink -f $0)
basedir="${basedir%/*}"
basedir="${basedir%/*}" # this assumes that the script sits in a subdirectory of $basedir
# Move to work directory
cd $basedir/python


# Define formatted date variables
date_tag="$( date +%Y.%m )"
date_file="$( date +%d%b%Y )"


# Checkout/create Git branch for updated versioned requirements files
if [ "$git_enabled" != 0 ] ; then
  git_branch_original="$( git branch --show-current )"
  git_branch_new="update/requirements-${date_file}"
  git checkout $git_branch_new
  if [ "$?" != "0" ] ; then
    git checkout -b $git_branch_new
  fi
fi


# Force update starting images
docker pull python:${py_ver}-slim
docker pull intelpython/intelpython3_core:${ipy_ver}

# Build and push image "hpc-python"
repo="hpc-python"
cd $repo
image="${repo}:${date_tag}"
echo " .. Now building $image"
# Generate versioned requirements file
mkdir -p .home_py
docker run --rm \
  -u $(id -u):$(id -g) \
  -v $(pwd):$(pwd) -w $(pwd) \
  --env date_file="${date_file}" --env HOME="$(pwd)/.home_py" \
  python:${py_ver}-slim bash -c 'pip3 install --user pip-tools && \
    $HOME/.local/bin/pip-compile requirements.in -o requirements-${date_file}.txt'
rm -rf .home_py
# Git add versioned requirements file
if [ "$git_enabled" != 0 ] ; then git add requirements-${date_file}.txt ; fi
# Build
docker build \
  --build-arg PY_VERSION="${py_ver}" \
  --build-arg MPICH_VERSION="${mpich_ver}" \
  --build-arg DATE_FILE="${date_file}" \
  -t quay.io/cnakhl/$image .
# Push
docker push quay.io/cnakhl/$image
cd ..

# Commit Git changes, and push new branch to remote
if [ "$git_enabled" != 0 ] ; then
  git commit -m "New versioned requirements files on ${date_file}" && \
    git push $git_remote $git_branch_new && \
    git checkout $git_branch_original && \
    git branch -d $git_branch_new
fi


echo ""
echo " Gone through all builds and pushes. Done!"
exit
