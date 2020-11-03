#!/bin/bash

set -x
set -e

echo "promoting changes in jx3-gitops-template to downstream templates"

declare -a repos=(
  # local
  "jx3-kubernetes" "jx3-kind-vault" "jx3-minikube" "jx3-docker-vault"
  # GKE
  "jx3-gke-vault" "jx3-gke-gsm" "jx3-gke-gcloud-vault" 
  # EKS
  "jx3-eks-terraform-vault" "jx3-eks-vault"
  # Azure
  "jx3-azure-terraform"
  # OpenShift
  "jx3-openshift" "jx3-openshift-crc"
)
export TMPDIR=/tmp/jx3-gitops-promote
rm -rf $TMPDIR
mkdir -p $TMPDIR

for r in "${repos[@]}"
do
  echo "upgrading repository https://github.com/jx3-gitops-repositories/$r"
  cd $TMPDIR
  git clone https://github.com/jx3-gitops-repositories/$r.git
  cd "$r"
  echo "recreating a clean version stream"
  rm -rf versionStream
  jx gitops kpt update || true
  kpt pkg get https://github.com/jenkins-x/jxr-versions.git/ versionStream
  rm -rf versionStream/jenkins*.yml versionStream/jx versionStream/.github versionStream/.pre* versionStream/.secrets* versionStream/OWNER* versionStream/.lighthouse
  jx gitops helmfile resolve --update
  git add * || true
  git commit -a -m "chore: upgrade version stream" || true
  git push || true
done

# lets upgarde our own infra automatically
LOCAL_BRANCH_NAME="jx-vs_$VERSION"
cd $TMPDIR
git clone https://github.com/jenkins-x/jx3-eagle.git
cd "jx3-eagle"
git checkout -b $LOCAL_BRANCH_NAME
jx gitops upgrade
git push origin $LOCAL_BRANCH_NAME
jx create pullrequest -t "chore: version stream upgrade" -l updatebot
