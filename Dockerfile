FROM ubuntu:18.04

ENV WORKSPACE_DIR /root
ENV FIRMWARE_DIR ${WORKSPACE_DIR}/Firmware
ENV SITL_RTSP_PROXY ${WORKSPACE_DIR}/sitl_rtsp_proxy

ENV DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
ENV DISPLAY :99
ENV LANG C.UTF-8

RUN apt-get update && \
    apt-get install -y bc \
                       vim \
                       cmake \
                       curl \
                       gazebo9 \
                       git \
                       gstreamer1.0-plugins-bad \
                       gstreamer1.0-plugins-base \
                       gstreamer1.0-plugins-good \
                       gstreamer1.0-plugins-ugly \
                       iproute2 \
                       libeigen3-dev \
                       libgazebo9-dev \
                       libgstreamer-plugins-base1.0-dev \
                       libgstrtspserver-1.0-dev \
                       libopencv-dev \
                       libroscpp-dev \
                       protobuf-compiler \
                       python3-jsonschema \
                       python3-numpy \
                       python3-pip \
                       unzip \
                       xvfb && \
    apt-get -y autoremove && \
    apt-get clean autoclean && \
    rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/* && \
    pip3 install --upgrade pip && \
    pip3 install empy \
                 future \
                 jinja2 \
                 kconfiglib \
                 packaging \
                 pyros-genmsg \
                 toml \
                 pyyaml

COPY hitl.patch ${WORKSPACE_DIR}/
RUN git clone https://github.com/PX4/PX4-Autopilot.git ${FIRMWARE_DIR} && \
    cd ${FIRMWARE_DIR} && \
    git checkout v1.13.2 && \
    git submodule update --init --recursive && \
    cd ${FIRMWARE_DIR}/Tools/sitl_gazebo && \
    git apply ${WORKSPACE_DIR}/hitl.patch && \
    cd ${FIRMWARE_DIR} && \
    DONT_RUN=1 make px4_sitl gazebo && \
    rm ${WORKSPACE_DIR}/*.patch

COPY gazebo_hitl_multiple_run.sh gazebo_sitl_multiple_run.sh \
     iris_hitl.sdf.jinja edit_rcS.bash entrypoint.sh /root/
RUN mv /root/gazebo_hitl_multiple_run.sh /root/gazebo_sitl_multiple_run.sh ${FIRMWARE_DIR}/Tools/ && \
    mv /root/iris_hitl.sdf.jinja ${FIRMWARE_DIR}/Tools/sitl_gazebo/models/iris_hitl/ && \
    chmod +x /root/entrypoint.sh ${FIRMWARE_DIR}/Tools/gazebo_hitl_multiple_run.sh \
                                 ${FIRMWARE_DIR}/Tools/gazebo_sitl_multiple_run.sh

#RUN ["/bin/bash", "-c", " \
#    cd ${FIRMWARE_DIR} && \
#    DONT_RUN=1 make px4_sitl gazebo && \
#    DONT_RUN=1 make px4_sitl gazebo \
#"]

COPY sitl_rtsp_proxy ${SITL_RTSP_PROXY}
RUN cmake -B${SITL_RTSP_PROXY}/build -H${SITL_RTSP_PROXY} && \
    cmake --build ${SITL_RTSP_PROXY}/build

ENTRYPOINT ["/root/entrypoint.sh"]
