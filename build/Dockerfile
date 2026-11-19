# Copied build pattern from hecknt/makepkg-action @ 6efd785524d744425796e65971a0c5db1b54c9ef
# Do not edit without also updating scripts/upstream-pins.env.
FROM docker.io/archlinux/archlinux:base-devel

COPY system_files /

RUN pacman -Syu --noconfirm --needed \
        git namcap sudo pacman-contrib tree && \
    useradd -m --shell=/bin/bash build && usermod -L build && \
    echo "build ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    echo "root ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

COPY entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
