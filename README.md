
# dotfiles

## Bootstrap

```bash
./bootstrap-mac.sh
```

## Installing packages

Brewfiles are opt-in. Run whichever you need:

```bash
brew bundle --file infrastructure/brewfile   # k8s, helm, terraform, docker
brew bundle --file personal-mac/brewfile     # nvim, tmux, firefox, VSCode
brew bundle --file language-specific/python/brewfile  # Python tooling
```

## GPG setup

```bash
gpg --default-new-key-algo rsa4096 --gen-key
gpg --list-secret-keys --keyid-format=long
gpg --armor --export <replace with value after rsa4096/> | pbcopy
```

## References
* https://docs.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#adding-your-ssh-key-to-the-ssh-agent
