# In development, do not use on your systems, thanks

## Todo

- Update Documentation
- Update kitty.conf
- Update hyprland bindings
- Figure out Materia on GTK and QT how to set both themes
- Configure waybar
- Configure rofi wifi, bluetooth selection
- Configure audio control playerctl
- Make matching colors in all configs

## Kickstarting

- You can easily get a new Arch machine going via my kickstart script in `.local/bin/`
- It creates a seperate ESP partition UEFI only supported
- Main partition uses btrfs with default Arch btrfs layout for snapper(e.g: seperate root, snapshot, home, var_log subvolumes)
- Only supports GRUB
- Use username `spidax` to automatically clone dotfiles and further configure your system

### Initating kickstart on archiso

```
bash <(curl -sL ks.rvq.lt)
```
