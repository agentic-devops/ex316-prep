# Lab 16: Basic system administration inside the guest

Objective 16. Namespace: `sysadmin-lab`. Everything here is done inside the VM
(`virtctl ssh cloud-user@vmi/sysadmin-vm -n sysadmin-lab`, then `sudo -i`).
Fedora is used for the lab; RHEL guests use the same commands.

## Tasks
1. `labweb.service` is installed but stopped. Start it, enable it at boot, and prove it answers on `localhost:8081`. Reboot the VM and confirm it came back.
2. `labapp.service` fails. Find the cause from `systemctl status` and `journalctl`, fix the unit, reload, start and enable it.
3. Install a package, verify it, remove it, and list what a package owns (`dnf install`, `rpm -ql`, `dnf remove`).
4. Add a package repository from a `.repo` file, list repos, disable one, and install from a specific repo.
5. Create a drop-in override for a unit (`systemctl edit`) that changes `Restart=`.
6. Set the hostname, timezone, and add a user with sudo rights.
7. Show listening ports, disk usage, memory and the last boot's errors.
8. Offline repair: with the VM stopped, inspect its disk using `virtctl guestfs`.

## Gotchas
- After editing a unit file you must run `systemctl daemon-reload`.
- `start` does not survive a reboot; `enable` does. `enable --now` does both.
- Failed units: `systemctl status -l <unit>` plus `journalctl -u <unit> -b --no-pager`.
- Packages need a reachable repo. On a disconnected cluster, point `dnf` at an internal mirror.
- `systemctl edit` creates `/etc/systemd/system/<unit>.d/override.conf`; use `--full` to replace the whole unit.
- Cloud-init runs once. Editing user-data later does not reconfigure a booted VM.

## Must-know commands
```bash
# services
systemctl status labweb
sudo systemctl enable --now labweb
systemctl is-enabled labweb ; systemctl is-active labweb
systemctl list-units --failed
systemctl list-unit-files --state=enabled | head
sudo systemctl daemon-reload
sudo systemctl edit labapp
journalctl -u labapp -b --no-pager | tail -20
sudo systemctl mask <unit> ; sudo systemctl unmask <unit>
curl -s localhost:8081

# packages
sudo dnf install -y tmux
rpm -q tmux ; rpm -ql tmux | head ; rpm -qf /usr/bin/tmux
sudo dnf remove -y tmux
dnf repolist ; dnf repolist --all
sudo dnf config-manager --set-disabled <repoid>
sudo dnf install --repo <repoid> <pkg>
dnf history ; dnf provides '*/semanage'
sudo tee /etc/yum.repos.d/lab.repo <<'EOF2'
[lab-base]
name=Lab base
baseurl=http://repo.example.com/base
enabled=1
gpgcheck=0
EOF2

# system
sudo hostnamectl set-hostname lab-vm
sudo timedatectl set-timezone UTC
sudo useradd -m -G wheel opsuser ; sudo passwd opsuser
ss -ltnp ; df -h ; free -m ; lsblk
journalctl -p err -b --no-pager | tail

# offline disk repair (VM stopped)
virtctl stop sysadmin-vm -n sysadmin-lab
virtctl guestfs sysadmin-vm-root -n sysadmin-lab
```
