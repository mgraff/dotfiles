#!/bin/sh

REPO_DIR=$(realpath $(dirname $0))

# Install symlinks
echo "* Installing *.symlink files"
find "${REPO_DIR}" -not -iwholename '*.git*' -name "*.symlink" -print | while read file
do
    dest="${HOME}/$(basename $(echo "${file}" | sed 's/.symlink$//'))"
    ln -sfnv "${file}" "${dest}"
done

# Install zprezto
echo "* Installing zprezto dotfiles"
find "${HOME}"/.zprezto/runcoms -type f \! -name 'README.md' | while read file
do
    ln -sfnv "${file}" "${HOME}/.$(basename "${file}")"
done

# Install kitty
if type kitty; then
    echo "* Installing kitty dotfiles"
    mkdir -p ${HOME}/.config
    ln -sfnv ${REPO_DIR}/kitty ${HOME}/.config/
fi
