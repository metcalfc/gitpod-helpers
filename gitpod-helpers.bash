function get_gitpod() {

  local gitpod_version="${1:=main.2278}"

  docker create -ti --name installer "eu.gcr.io/gitpod-core-dev/build/installer:${gitpod_version}"

  docker cp installer:/app/installer ./gitpod-installer
  docker rm -f installer
}

function init_gitpod() {
    local config_file="${1:=./config.yaml}"
    ./gitpod-installer init > ${config_file}
}

function mirror_gitpod() {

  local config_file="${1:=./config.yaml}"

  for row in $(./gitpod-installer mirror list --config ${config_file} | jq -c '.[]'); do
    original=$(echo ${row} | jq -r '.original')
    target=$(echo ${row} | jq -r '.target')
    docker pull ${original}
    docker tag ${original} ${target}
    docker push ${target}
  done
}

function generate_airgap() {

  local config_file="${1:=./config.yaml}"
  local load_list=()

  # truncate and reset the push script
  echo "#!/bin/sh" > ./gitpod-push-mirror.sh
  for row in $(./gitpod-installer mirror list --config ${config_file} | jq -c '.[]'); do
    local original=$(echo ${row} | jq -r '.original')
    local target=$(echo ${row} | jq -r '.target')
    docker pull ${original}
    docker tag ${original} ${target}
    echo "docker push ${target}" >> ./gitpod-push-mirror.sh
    load_list+=( ${target} )
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
  docker save -o gitpod.tar ${load_list[*]}

}
