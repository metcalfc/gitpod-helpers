
function gitpod() {
  # Set the version to use - see https://werft.gitpod-dev.com for available values
  local GITPOD_INSTALLER_VERSION="${GITPOD_INSTALLER_VERSION:-release-2022.01.12}"

  # Check docker is available
  which docker > /dev/null || (echo "Docker not installed - see https://docs.docker.com/engine/install" && exit 1)

  # Now, run the Installer
  docker run -it --rm \
      -v="${HOME}/.kube:${HOME}/.kube" \
      -v="${PWD}:${PWD}" \
      -w="${PWD}" \
      "eu.gcr.io/gitpod-core-dev/build/installer:${GITPOD_INSTALLER_VERSION}" \
      "${@}"
}


function get_gitpod() {

  curl -fsSLO https://github.com/gitpod-io/gitpod/releases/download/2022.02.0/gitpod-installer-linux-amd64
  curl -fsSLO https://github.com/gitpod-io/gitpod/releases/download/2022.02.0/gitpod-installer-linux-amd64.sha256
  sha256sum -c gitpod-installer-linux-amd64.sha256 || (echo "Checksum mismatch - aborting" && exit 1)
  chmod +x gitpod-installer-linux-amd64
  mv gitpod-installer-linux-amd64 ./gitpod-installer

}

function init_gitpod() {
  local config_file="${PWD}/config.yaml"

  ./gitpod-installer init > "${config_file}"
  yq e -i ".repository = \"${1}\"" "${config_file}"
}

function mirror_gitpod() {

  local config_file="${PWD}/config.yaml"

  for row in $(./gitpod-installer mirror list --config ${config_file} | jq -c '.[]'); do
    original=$(echo "${row}" | jq -r '.original')
    target=$(echo "${row}" | jq -r '.target')
    docker pull "${original}"
    docker tag "${original}" "${target}"
    docker push "${target}"
  done
}

function generate_airgap() {

  local config_file="${PWD}/config.yaml"
  local load_list=()

  # truncate and reset the push script
  echo "#!/bin/sh" > ./gitpod-push-mirror.sh
  for row in $(./gitpod-installer mirror list --config ${config_file} | jq -c '.[]'); do
    local original=$(echo "${row}" | jq -r '.original')
    local target=$(echo "${row}" | jq -r '.target')
    docker pull "${original}"
    docker tag "${original}" "${target}"
    echo "docker push ${target}" >> ./gitpod-push-mirror.sh
    load_list+=( "${target}" )
  done

  echo "Saving the images to a tarball. This will take some time."
  echo "This tarball is ~18G and can be compressed by 60% with gzip."
  echo
  echo "  gzip gitpod.tar"
  echo
  echo "Compression of an archive this large will take 10+ minutes."
  echo "You'll need to move the tarball and push script to the remote"
  echo "system. If you compressed it, decompress it, and then load it with:"
  echo
  echo "  scp gitpod.tar gitpod-push-mirror.sh admin@bastion:"
  echo "  docker load -i gitpod.tar"
  echo
  echo "You can then push all the images to their final destination with the"
  echo "push script run on a host that has push access to the mirror repos."
  echo
  echo "  sh gitpod-push-mirror.sh"
  docker save -o gitpod.tar "${load_list[@]}"

}
