# Minikube WSL sync

Based on the following Medium post: [Setting up Kubernetes on WSL to work with Minikube on Windows 10](https://blog.thepolyglotprogrammer.com/setting-up-kubernetes-on-wsl-to-work-with-minikube-on-windows-10-90dac3c72fa1)

## Problem statement

By default it is not trivial to access a cluster that is running inside WSL from a browser on Windows.

One way to solve this is to install [minikube](https://minikube.sigs.k8s.io/docs/) directly on Windows and have a mechanism to synchronize
WSL kubernetes configuration in order to be able to use [kubectl](https://kubernetes.io/docs/reference/kubectl/overview/) inside WSL
to manage the cluster on Windows host (created with minikube).

This script tries to solve this problem by syncronizing local `~/.kube/config` configuration file inside WSL with the server on Windows
at the each start of the shell session, which should be adequate for the most use cases.

It initializes a completely new `~/.kube/config` configuration file (backing up the previous one, if present).
After that on each shell start it checks `clusters.cluster.server` property of the cluster with the mane `minikube` on
Windows host and updates it inside WSL:

```diff
apiVersion: v1
clusters:
  - cluster:
      certificate-authority: /mnt/c/Users/<user>/.minikube/ca.crt
-     server: https://127.0.0.1:56028
+     server: https://127.0.0.1:64767
    name: minikube
```

## Installation

### Install `minikube` using `chocolatey`

Chocolatey is a package manager for Windows: https://chocolatey.org/install

Install `minikube`: https://community.chocolatey.org/packages/Minikube

```powershell
choco install minikube
```

### Download the script into your home directory

```bash
curl -fsSL https://raw.githubusercontent.com/lexuzieel/minikube-wsl-sync/master/sync.sh > ~/minikube-wsl-sync.sh
```

### Install yq

The easiest way to install is using webi:

```bash
curl -sS https://webinstall.dev/yq@4 | bash
```

If you don't want to use webi, you can install it in a number of other ways:
https://github.com/mikefarah/yq#install

### Update your shell profile (`.bashrc`, `.zshrc`, etc)

Add the following line at the end of your profile script:

```bash
[[ -f ~/minikube-wsl-sync.sh ]] && source ~/minikube-wsl-sync.sh
```

## Usage

Start the new shell session - this script will automatically
discover Windows installation of minikube and refresh the server address
to point towards the server on Windows host.

```bash
$ which minikube
minikube: aliased to /mnt/c/ProgramData/chocolatey/bin/minikube.exe
```

Start the cluster:

```bash
$ minikube start
```

Check the status:

```bash
$ minikube status
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

Using `kubectl` installed inside WSL you can manage your cluster:

```bash
$ kubectl get nodes
NAME       STATUS   ROLES                  AGE   VERSION
minikube   Ready    control-plane,master   15h   v1.20.2
```
