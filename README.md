# In development, do not use on your systems for your own safety, thanks

## Todo

- Update Documentation
- Update kitty.conf
- Update hyprland bindings
- Configure waybar
- Configure rofi wifi, bluetooth selection
- Make matching colors in all configs
- Add dunst config
- Review missing packages
- Write recovery instructions for a drive / package failure

## Kickstarting

- You can easily get a new Arch machine going via my kickstart script in `.local/bin/`
- It creates a seperate ESP partition UEFI only supported
- Main partition uses btrfs with default Arch btrfs layout for snapper(e.g: seperate root, snapshot, home, var_log subvolumes)
- Only supports GRUB
- Use username `spidax` to automatically clone dotfiles and further configure your system
- If using my username with init.sh remove the lines regarding decryption, ssh ang gpg configuration it will fail to decrypt without my password (left in for testing purposes for now)

### Initating kickstart on archiso

```
bash <(curl -sL ks.rvq.lt)
```

## After install

- Import firefox profile via sync
- Set keyboard in waybar config via `hyprctl devices` see waybar gh wiki hyprland module for more info
