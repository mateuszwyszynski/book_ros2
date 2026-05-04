FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install common dependencies
RUN apt update && apt upgrade -y && \
    apt install -y zsh tzdata ca-certificates wget curl nano neovim less git build-essential software-properties-common cmake sudo iproute2 htop && \
    add-apt-repository universe && apt update && \
    rm /etc/localtime && ln -s /usr/share/zoneinfo/Europe/Warsaw /etc/localtime

# Install uv
RUN mkdir /tmp/uv && cd /tmp/uv && wget https://github.com/astral-sh/uv/releases/download/0.8.3/uv-x86_64-unknown-linux-gnu.tar.gz -O uv.tar.gz && \
    tar -xzf uv.tar.gz && cd uv-x86_64-unknown-linux-gnu && mkdir /opt/uv && install uv uvx /opt/uv
ENV PATH="/opt/uv:$PATH"

# Install ROS
RUN export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}') && \
    curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo $VERSION_CODENAME)_all.deb" && \
    sudo dpkg -i /tmp/ros2-apt-source.deb && \
    sudo apt update && sudo apt install -y ros-dev-tools ros-jazzy-desktop ros-jazzy-rmw-cyclonedds-cpp
# This implementation is more reliable, e.g. see https://github.com/ros2/rmw_fastrtps/issues/786
ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

# User setup
ARG USERNAME=dev
ARG UID
ARG GID
RUN userdel -r ubuntu && groupadd -g $GID -o $USERNAME 2>/dev/null && \
    useradd -m -u $UID -g $GID -o -s /bin/zsh -d /home/$USERNAME $USERNAME 2>/dev/null && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME && \
    chmod 440 /etc/sudoers.d/$USERNAME
USER ${USERNAME}
RUN echo "export ROS_DOMAIN_ID=$((${UID} % 102))" >> ~/.zshenv && \
    echo "export ROS_DOMAIN_ID=$((${UID} % 102))" >> ~/.bashrc && \
    echo "export QT_XCB_GL_INTEGRATION=none" >> ~/.zshenv && \
    echo "export QT_XCB_GL_INTEGRATION=none" >> ~/.bashrc && \
    echo "source /opt/ros/jazzy/setup.zsh" >> ~/.zshenv && \
    echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc

# Setup python environment (track https://github.com/ros2/ros2/issues/1094)
ENV UV_LINK_MODE=copy
ENV UV_PROJECT_ENVIRONMENT="/home/${USERNAME}/.venv"
RUN uv venv --system-site-packages -p /usr/bin/python3 $UV_PROJECT_ENVIRONMENT
ENV PATH="$UV_PROJECT_ENVIRONMENT/bin:$PATH"

# Rosdep update
RUN sudo rosdep init && rosdep update --include-eol-distros

# Install python dependencies (mainly for Interbotix workspace)
RUN --mount=type=cache,target=/home/${USERNAME}/.cache/uv,uid=${UID},gid=${GID} \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen

# Project workspace setup
USER root
RUN mkdir -p    /workspace/bookros2_ws/src \
                /workspace/bookros2_ws/build \
                /workspace/bookros2_ws/install \
                /workspace/bookros2_ws/log && \
    chown -R ${USERNAME}:${USERNAME} /workspace
USER ${USERNAME}

RUN --mount=type=bind,source=.,target=/workspace/bookros2_ws/src/book_ros2 \
    cp /workspace/bookros2_ws/src/book_ros2/third_parties.repos /tmp/ && \
    cd /workspace/bookros2_ws/src && vcs import . < /tmp/third_parties.repos

RUN cd /workspace/bookros2_ws && \
    . /opt/ros/jazzy/setup.sh && \
    rosdep install --from-paths src --ignore-src -r -y

RUN cd /workspace/bookros2_ws && \
    . /opt/ros/jazzy/setup.sh && \
    colcon build --symlink-install

RUN echo "source /workspace/bookros2_ws/install/setup.zsh" >> ~/.zshenv && \
    echo "source /workspace/bookros2_ws/install/setup.bash" >> ~/.bashrc
