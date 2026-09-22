# Solution: Objective 16 (matches questions/16-sysadmin.md)

## Task 1: start and enable labweb
```bash
sudo systemctl enable --now labweb.service
systemctl is-enabled labweb ; systemctl is-active labweb
sudo reboot                      # or: virtctl restart q16-vm -n q16-sysadmin from outside
# after reboot:
systemctl is-active labweb
```

## Task 2: diagnose and fix labapp
```bash
systemctl status labapp.service
journalctl -u labapp -b --no-pager | tail -20
# typo found, e.g. "pyton3" instead of "python3":
sudo sed -i 's/pyton3/python3/' /etc/systemd/system/labapp.service
sudo systemctl daemon-reload
sudo systemctl enable --now labapp.service
systemctl status labapp.service
```

## Task 3: package install/remove
```bash
sudo dnf install -y tmux
rpm -q tmux
sudo dnf remove -y tmux
rpm -q tmux           # "package tmux is not installed"
```

## Task 4: drop-in override
```bash
sudo systemctl edit labweb.service
# in the editor, add:
#   [Service]
#   Restart=always
sudo systemctl daemon-reload
sudo systemctl restart labweb.service
cat /etc/systemd/system/labweb.service.d/override.conf
```

## Task 5: report state
```bash
ss -ltnp
df -h
systemctl list-units --failed
```
