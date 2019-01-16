#!/bin/sh

REPO_DIR=$(realpath $(dirname $0))

# Install symlinks
find "${REPO_DIR}" -not -iwholename '*.git*' -name "*.symlink" -print | while read file
do
    dest="${HOME}/$(basename $(echo "${file}" | sed 's/.symlink$//'))"
    ln -sfv "${file}" "${dest}"
done

# Install zprezto
find "${HOME}"/.zprezto/runcoms -type f \! -name 'README.md' | while read file
do
    ln -sfv "${file}" "${HOME}/.$(basename "${file}")"
done
