
# dotfiles
> Run `./bootstrap.sh` or use individual commands

```bash
gpg --default-new-key-algo rsa4096 --gen-key
gpg --list-secret-keys --keyid-format=long
gpg --armor --export <replace with value after rsa4096/> | pbcopy
```

References: 
* https://docs.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#adding-your-ssh-key-to-the-ssh-agent
