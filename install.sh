#!/bin/sh

REPO_DIR=$(realpath $(dirname $0))

find "${REPO_DIR}" -name "*.symlink" -print | while read file
do
  dest="${HOME}/$(basename $(echo "${file}" | sed 's/.symlink$//'))"
  ln -sfv "${file}" "${dest}"
done
