# install dependencies
# tmux           used for monitoring secondary processes
# sudo           for running specific commands as root
# git            for source countrol
# pwgen          for creating randomized passwords/secrets on the fly
# ncdu           file navigation
# unzip          file extraction and compression
# libicu         powershell dependency
# rsync          folder structure copying
# python         to run the mkdocs build
dnf install -y --setopt=install_weak_deps=False tmux sudo git pwgen ncdu libicu unzip python3 python3-pip rsync
dnf clean all