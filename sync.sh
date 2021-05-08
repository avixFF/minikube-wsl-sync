#!/bin/bash

# MIT License
#
# Copyright (c) 2021 Aleksei Ivanov
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

#
# This script synchronizes Windows installation of minikube with WSL.
# You do no need to install minikube inside WSL - this script automatically
# discovers Windows installation of minikube and refreshes server address
# to point towards the server on Windows host.
#
# Requirements:
# - yq (version 4) - easiest way to install is using webi:
#   curl -sS https://webinstall.dev/yq@4 | bash
#
# Currently it only supports default cluster & user named "minikube".

# Continue only if WSL is detected
if grep -qEi "(Microsoft|WSL)" /proc/version &>/dev/null; then
    # Define Windows user profile and program data paths
    # if they aren't already defined
    #
    # NOTE: `wslvar` WILL introduce shell startup lag, a workaroud for
    #       this is to cache its output somehow (i.e. runcached)
    #
    # Runcached:
    # https://gist.github.com/akorn/51ee2fe7d36fa139723c851d87e56096
    #
    if [[ -z "$WIN_HOME" ]]; then
        if which runcached &>/dev/null; then
            WIN_HOME=$(wslpath "$(runcached wslvar USERPROFILE)")
        else
            WIN_HOME=$(wslpath "$(wslvar USERPROFILE)")
        fi
    fi

    if [[ -z "$WIN_PROGRAM_DATA" ]]; then
        if which runcached &>/dev/null; then
            WIN_PROGRAM_DATA=$(wslpath "$(runcached wslvar PROGRAMDATA)")
        else
            WIN_PROGRAM_DATA=$(wslpath "$(wslvar PROGRAMDATA)")
        fi
    fi

    # Define DOCKER_CERT_PATH to point to WSL host, if it isn't already defined
    if [[ -z "$DOCKER_CERT_PATH" ]]; then
        DOCKER_CERT_PATH="$WIN_HOME/.minikube/certs"
    fi

    # Add minikube alias

    # Check if minikube was installed using Chocolatey on Windows host
    if which "$WIN_PROGRAM_DATA/chocolatey/bin/minikube.exe" >&/dev/null; then
        alias minikube="$WIN_PROGRAM_DATA/chocolatey/bin/minikube.exe"
    fi

    # If kubernetes configuraton exists on Windows host
    if [[ -f "$WIN_HOME/.kube/config" ]]; then
        # If kubernetes configuraton doesn't exist in WSL guest,
        # create a default one that points towards Windows host
        if [[ ! -f ~/.kube/config ]]; then
            touch ~/.kube/config
            chmod 700 ~/.kube/config # Prevent "This is insecure" warning
            cat <<EOT >~/.kube/config
apiVersion: v1
clusters:
  - cluster:
      certificate-authority: $WIN_HOME/.minikube/ca.crt
    name: minikube
contexts:
  - context:
      cluster: minikube
      user: minikube
    name: minikube
current-context: minikube
kind: Config
preferences: {}
users:
  - name: minikube
    user:
      client-certificate: $WIN_HOME/.minikube/profiles/minikube/client.crt
      client-key: $WIN_HOME/.minikube/profiles/minikube/client.key
EOT
        fi

        MINIKUBE_HOST="$(yq e '.clusters.[] | select(.name == "minikube") | .cluster.server // "UNABLE_TO_FIND_HOST_FILE"' "$WIN_HOME/.kube/config")"

        # Update minikube server address to point towards Windows host
        if [[ -f ~/.kube/config ]] && [[ -n "$MINIKUBE_HOST" ]]; then
            yq --inplace e "(.clusters.[] | select(.name == \"minikube\") | .cluster.server) = \"$MINIKUBE_HOST\"" ~/.kube/config
        fi
    fi
fi
