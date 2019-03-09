###############################################################################
# Build code-server from source code
###############################################################################
FROM node:8.15.0 as coder-binary

# Install VS Code's deps. These are the only two it seems we need.
RUN apt-get update && apt-get install -y \
	libxkbfile-dev \
	libsecret-1-dev

# Ensure latest yarn.
RUN npm install -g yarn@1.13

WORKDIR /src

COPY build build
COPY packages packages
COPY rules rules
COPY scripts scripts

COPY package.json .
COPY tsconfig.json .
COPY tslint.json .
COPY yarn.lock .

# In the future, we can use https://github.com/yarnpkg/rfcs/pull/53 to make yarn use the node_modules
# directly which should be fast as it is slow because it populates its own cache every time.
RUN yarn && yarn task build:server:binary


###############################################################################
# Install custom extensions
###############################################################################
FROM ubuntu:18.10 as vscode-env
ARG DEBIAN_FRONTEND=noninteractive

# Install the actual VSCode to download configs and extensions
RUN apt-get update && \
	apt-get install -y curl && \
	# VSCode missing deps
	apt-get install -y libx11-xcb1 libasound2  && \
	curl -o vscode-amd64.deb -L https://vscode-update.azurewebsites.net/latest/linux-deb-x64/stable && \
	dpkg -i vscode-amd64.deb || true && \
	apt-get install -y -f && \
	rm -f vscode-amd64.deb

# This gets user config from gist, parse it and install exts with VSCode
RUN code -v --user-data-dir /root/.config/Code

COPY extensions .
RUN while read -r line; do \
    echo "### INSTALL VS Code extension $line"; \
	code --user-data-dir /root/.config/Code --install-extension $line; \
	done < extensions
RUN ls -la /root/.vscode/extensions


###############################################################################
# Build final image
###############################################################################
# We deploy with ubuntu so that devs have a familiar environment.
FROM ubuntu:18.10
EXPOSE 8443
RUN apt-get update && apt-get install -y \
	openssl net-tools git git-crypt
RUN apt-get install -y locales && \
	locale-gen en_US.UTF-8
RUN apt-get install -y curl
RUN curl -LO https://github.com/BurntSushi/ripgrep/releases/download/0.10.0/ripgrep_0.10.0_amd64.deb && \
    dpkg -i ripgrep_0.10.0_amd64.deb
RUN apt-get install -y exuberant-ctags
# We unfortunately cannot use update-locale because docker will not use the env variables
# configured in /etc/default/locale so we need to set it manually.
ENV LANG=en_US.UTF-8

RUN useradd -ms /bin/bash user

COPY --from=coder-binary /src/packages/server/cli-linux-x64 /usr/local/bin/code-server
COPY --from=vscode-env /root/.vscode/extensions /home/user/.code-server/extensions

RUN mkdir -p /home/user/.local/share/code-server
RUN mkdir -p /home/user/.cache/code-server/logs
RUN chown -R user:user /home/user

USER user
WORKDIR /home/user/project
# Unfortunately `.` does not work with code-server.
CMD code-server $PWD
