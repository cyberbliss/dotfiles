# Dotfile repo

Contains my profiles for installing and configuring Linux & Mac instances.  
Based on this series of blog posts: <https://haseebmajid.dev/posts/2022-10-15-how-to-manage-your-dotfiles-with-dotbot/>

## Usage
`make install profile="<profile from meta/profiles>"`

### Mac profiles
Install brew before running dotbot:  
`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

If you get a permissions error try this:

```
sudo chown -R $(whoami) $(brew --prefix)/*
/usr/local/bin/brew update --force --quiet
brew doctor
```

`gcloud` is installed as part of Brewfile, but it is not initialised. To do this, ensure you have already authenticated with your GCP account and execute `gcloud init`. The installation is minimal, use `gcloud components list` to see what components are installed.

### Ubuntu Coder
Use this one for the Linux VM spun up by Coder: `make install profile="ubuntu-coder"`  

Installs: the basics using `apt`, Homebrew and sets the default shell to `zsh`. Once complete log out and back in again and then: `brew bundle -v`

## TODO

- https://haseebmajid.dev/posts/2022-12-15-how-to-use-dotbot-to-personalise-your-vscode-devcontainers/