# Entando CLI tools

# Requirements:

## Main requirement: BASH

the scripts are written in bash, however the activation/deactivation/auto-install scripts should be capable to run also in zsh

## Windows Users

You can obtain a bash version for windows by installing either:

- Git for windows
- Minimalistic GNU for Windows (MinGW)

_be sure the bash executable is in path_


## Other requirement

_run the dependencies checker_

# Installation

## On the fly:

```
curl https://<ent-url>/auto-install | ENTANDO_RELEASE=[entando-release-tag] bash
```

please note that the ENTANDO_RELEASE is the tag of the Entando release under:  
`https://github.com/entando/entando-releases/`

## Manual download:

_clone/download the project and then:_
```
<ent-path>/auto-install [entando-release-tag]
```

# Help

```
<ent-path>/bin/ent-help.sh
```

# Activation

```
source <ent-path>/activate
```
_from bash or a zsh variant_

# Directory structure:

```
s/    => support scripts and bins
w/    => work/status dir (gitignored)
dist/ => distribution files
lib/  => additional dependencies installed by ent
bin/  => the entando cli tools
```
