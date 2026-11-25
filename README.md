# Entando CLI

# Requirements:

## Main requirement: BASH

the scripts are written in bash, however the activation/deactivation/auto-install scripts should be capable to run also in zsh

## Windows Users

You can obtain a bash version for windows by installing either:

- Git for windows
- Minimalistic GNU for Windows (MinGW)

_be sure the bash executable is in path_

## macOS on Apple Silicon (M1, M2, ...)

ent installs a private Node.js 14, which has no native Apple Silicon build: `ent check-env` installs the official
x64 build, which runs through Rosetta 2. If Rosetta 2 is missing, `ent check-env` offers to install it; you can also
install it yourself with:

```
softwareupdate --install-rosetta --agree-to-license
```

On Linux arm64 hosts the native arm64 build of Node.js 14 is installed.


## Other requirement

_run the environment dependencies checker_

```
ent check-env {mode}
```

# Installation

## On the fly:

```
curl https://<ent-url>/auto-install | ENTANDO_RELEASE={entando-release-tag} bash
```
or
```
bash <(curl "https://<ent-url>/entando/entando-cli/develop/auto-install") --release "{entando-release-tag}" 
[--cli-version "{entando-release-tag}"]
```


please note that the {entando-release-tag} is the tag of the Entando release under:

- https://github.com/entando/entando-releases/


## Manual download:

_clone/download the project and then:_
```
<ent-path>/auto-install [entando-release-tag]
```

# Help

```
ent help
```

or

```
ent {command} --help
```

# Activation

```
source <ent-path>/activate
```

_from bash or a zsh variant_

# Directory structure:

```
s/       => support scripts and bins
w/       => work/status dir (gitignored)
dist/    => distribution files
opt/     => additional dependencies and packages installed by ent
bin/     => the entando cli main script
bin/mod  => the implementations of the entando cli commands
```
