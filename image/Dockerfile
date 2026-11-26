FROM debian:trixie

# libexpat1, libncursesw6, libmpc3, libmpfr6: RISC-V toolchains. perl, zlib1g-dev: verilator.
RUN apt-get update && apt-get install -y --no-install-recommends \
      bc bison build-essential ca-certificates clang-format curl file flex gawk git jq less \
      libexpat1 libmpc3 libmpfr6 libncursesw6 librsvg2-bin libxml2-utils neovim perl procps \
      python3 python3-pip python3-venv ripgrep tmux unzip xz-utils zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Vivado xsim: libtinfo.so.5 (dropped after bookworm) and the locale its scripts set in LC_ALL.
RUN curl -fsSLo /tmp/libtinfo5.deb \
      https://deb.debian.org/debian/pool/main/n/ncurses/libtinfo5_6.4-4_amd64.deb \
    && echo 'dd347f794e651039e7b4c391f86c674fed7f415b3dca6b0937beb0d470f09c1a  /tmp/libtinfo5.deb' \
      | sha256sum -c - \
    && dpkg -i /tmp/libtinfo5.deb && rm /tmp/libtinfo5.deb
RUN apt-get update && apt-get install -y --no-install-recommends locales \
    && rm -rf /var/lib/apt/lists/* \
    && echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && locale-gen

# From iob-soc-int install_core.sh, except verible (mounted).
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir \
      matplotlib mypy==1.19.1 black==26.3.1 numpy scipy parse pyserial wavedrom

# Login shells reset PATH, and tmux starts login shells by default.
RUN echo 'set -g default-command bash' > /etc/tmux.conf

RUN useradd -m -u 1000 -s /bin/bash agent
USER agent
WORKDIR /home/agent
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && echo '{"hasCompletedOnboarding":true}' > /home/agent/.claude.json
COPY --chown=agent:agent home/ /home/agent/
RUN ln -s .gitconfig.work /home/agent/.gitconfig
ENV HOME=/home/agent \
    PATH=/home/agent/.local/bin:/opt/venv/bin:/usr/local/bin:/usr/bin:/bin \
    LANG=C.UTF-8
CMD ["bash"]
