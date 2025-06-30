# Global Build Arguments
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

#
# Multi Stage: Dev Image
#

FROM nvidia/cuda:12.6.3-cudnn-devel-ubuntu22.04 AS dev

# Arguments associated with the non-root user
ARG USERNAME
ARG USER_UID
ARG USER_GID

# Set environemntal variables
ENV POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_HOME=/home/${USERNAME}/poetry \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive

# Add poetry executable to PATH
ENV PATH="$POETRY_HOME/bin:$PATH"

# Add the non-root user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    git-lfs \
    # Below is python's system dependencies
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libffi-dev \
    liblzma-dev \
    && rm -rf /var/lib/apt/lists/*

# Switch to the non-root user to install applications on the user level
USER ${USERNAME}

# Explicitly populate home directory variable
ENV HOME=/home/${USERNAME}

# Install pyenv
RUN curl https://pyenv.run | bash

# Add pyenv executable to PATH
ENV PYENV_ROOT=${HOME}/.pyenv
ENV PATH=$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH

# Install python
RUN pyenv install 3.12.9 && \
    pyenv global 3.12.9

# Verify python installation
RUN python --version

# Install poetry
RUN mkdir -p ${HOME}/poetry && \
    curl -sSL https://install.python-poetry.org | python - && \
    poetry self add poetry-plugin-up

# Verify Poetry installation
RUN poetry --version

#
# Multi Stage: Bake Image
#

FROM dev AS bake

# Arguments associated with the non-root user
ARG USERNAME
ARG USER_UID
ARG USER_GID

# Make working directory
RUN mkdir -p ${HOME}/app

# Set working directory
WORKDIR ${HOME}/app

# Copy source code and python dependency specification
COPY pyproject.toml poetry.lock README.md ${HOME}/app/
COPY src ${HOME}/app/src

# Install python runtime dependencies in container
RUN poetry install --without dev

#
# Multi Stage: Runtime Image
#

FROM nvidia/cuda:12.6.3-cudnn-runtime-ubuntu22.04 AS runtime

# Arguments associated with the non-root user
ARG USERNAME
ARG USER_UID
ARG USER_GID

# Set environemntal variables
ENV PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive

# Add the non-root user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    # Below is python's system dependencies
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libffi-dev \
    liblzma-dev \
    && rm -rf /var/lib/apt/lists/*

# Switch to the non-root user to install applications on the user level
USER ${USERNAME}

# Explicitly populate home directory variable
ENV HOME=/home/${USERNAME}

# Install pyenv
RUN curl https://pyenv.run | bash

# Add pyenv executable to PATH
ENV PYENV_ROOT=${HOME}/.pyenv
ENV PATH=$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH

# Install python
RUN pyenv install 3.12.9 && \
    pyenv global 3.12.9

# Verify python installation
RUN python --version

# Copy over baked environment
# Explicitly copy the maybe ignored .venv folder
COPY --from=bake /home/${USERNAME}/app /home/${USERNAME}/app
COPY --from=bake /home/${USERNAME}/app/.venv /home/${USERNAME}/app/.venv

# Switch to the non-root user
USER ${USERNAME}

# Set working directory
WORKDIR /home/${USERNAME}/app

# Set executables in PATH
ENV PATH="/home/${USERNAME}/app/.venv/bin:$PATH"

# Expose the service port
EXPOSE 80

# Implement an health check
# HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
#   CMD curl -f http://localhost:80/health-check || exit 1

# Auto start the fastapi service on start-up
# ENTRYPOINT ["fastapi", "run", "src/medusa/main.py", "--port", "80"]

