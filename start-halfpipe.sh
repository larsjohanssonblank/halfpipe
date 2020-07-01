#!/bin/bash

set -e  # exit after any failure

HP_VERSION=1
ORA_VERSION=19.5
K8S_VERSION=v1.13.1  # include k8s leading 'v'

image_name=halfpipe
script_dir=`dirname $0`
build_dir="${script_dir}/image"
image_tag=${HP_VERSION}
image_already_built=`docker images --filter=reference=${image_name}:${image_tag} -q | wc -l`
default_port=8080
default_aws_profile=halfpipe

usage() {
  echo
  echo "Usage: $0 [ -a <AWS profile name> ] [-b] [-k] [-p <port>]" 1>&2
  echo ""
  echo "    Start Halfpipe in a Docker container preconfigured with Oracle Instant Client ${ORA_VERSION}"
  echo "    where:"
  echo ""
  echo "   -a  supplies a profile name found in ~/.aws/credentials, to set AWS access keys in the container (default: ${default_aws_profile})"
  echo "   -b  forces a Docker image build, else I will build once and run image, $image_name:$image_tag"
  echo "   -k  mounts .kube/config into the container so you can launch Kubernetes jobs easily"
  echo "   -p  port to expose for Halfpipe's micro-service used by 'hp pipe' commands (default: $default_port)"
  echo
  exit 1
}

while getopts ":a:fbkp:" o; do
  case "${o}" in
    a)
      aws_profile=${OPTARG};;
    b)
      build_requested=1;;
    k)
      kube=1;;
    p)
      port=${OPTARG};;
    *)
      usage;;
  esac
done
shift $((OPTIND-1))

if [[ -z "${profile}" ]]; then  # if the profile has NOT been set...
  aws_profile="${default_aws_profile}"  # use the default.
fi

if [[ "$kube" -eq 1 ]]; then  # if we should mount .kube/config...
  kube_mount="-v ~/.kube:/home/dataops/.kube"
fi

if [[ -z "$port" ]]; then  # if the port has NOT been set...
  port=$default_port
fi


# Build Halfpipe.
if [[ "$build_requested" -eq 1 || "$image_already_built" -ne 1 ]]; then  # if we should build halfpipe...
  cmd="docker build \\
    --build-arg HP_VERSION=${HP_VERSION} \\
    --build-arg ORA_VERSION=${ORA_VERSION} \\
    --build-arg K8S_VERSION=${K8S_VERSION} \\
    -t ${image_name}:${image_tag} \\
    \"${build_dir}\""
  echo "${cmd}"
  eval "${cmd}"
fi

# Create if not exists the halfpipe home dir.
mkdir -p ~/.halfpipe

# Add defaults for the first time.
if [[ ! -f "$HOME/.halfpipe/config.yaml" ]]; then  # if there are no existing config defaults...
  echo "Using default config file config.yaml"
  cp "${script_dir}/.default-config.yaml" "$HOME/.halfpipe/config.yaml"
fi

# Start Halfpipe container.
echo "Starting ${image_name}:${image_tag} using AWS profile \"${aws_profile}\"..."
cmd="docker run -ti --rm \\
    -v ~/.halfpipe:/home/dataops/.halfpipe \\
    -v ~/.aws:/home/dataops/.aws \\
    -e AWS_PROFILE=\"${aws_profile}\" \\
    ${kube_mount} \\
    -p ${port}:8080 \\
    ${image_name}:${image_tag}"
eval "$cmd"
