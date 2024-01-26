#!/bin/bash

function show_help {
    if [ xunset = x"${vehicle}" ]; then
        if [ $DO_HITL -eq 0 ]; then
            vehicle=iris
        else
            vehicle=iris_hitl
        fi
    fi
    echo ""
    echo "Usage: ${0} [-h | -v VEHICLE | -w WORLD | -c COUNT | -a IP_API | -q IP_QGC]"
    echo ""
    echo "Run a headless px4-gazebo simulation in a docker container. The"
    echo "available vehicles and worlds are the ones available in PX4"
    echo "(i.e. when running e.g. \`make px4_sitl gazebo_iris__baylands\`)"
    echo ""
    echo "  -a    Set the API IP (default: localhost)"
    echo "  -b    Set the PX4 baud rate (default: 921600)"
    echo "  -c    Set the instance count (default: 1)"
    echo "  -h    Show this help"
    echo "  -H    Perform hardware in the loop simulation"
    echo "  -q    Set the QGroundControl IP (default: localhost)"
    echo "  -s    Set the serial port root (default: /dev/ttyACM)"
    echo "  -v    Set the vehicle (default: ${vehicle})"
    echo "  -w    Set the world (default: empty)"
    echo ""
    echo "  <IP_API> is the IP to which PX4 will send MAVLink on UDP port 14540"
    echo "  <IP_QGC> is the IP to which PX4 will send MAVLink on UDP port 14550"
    echo ""
    echo "By default, MAVLink is sent to the host."
}

OPTIND=1 # Reset in case getopts has been used previously in the shell.

serial=/dev/ttyACM
baud=921600

vehicle=unset
world=empty
count=1
DO_HITL=0

while getopts "a:b:c:h?Hq:s:v:w:" opt; do
    case "$opt" in
    a)  IP_API=$OPTARG
        ;;
    b)  baud=$OPTARG
        ;;
    c)  count=$OPTARG
        ;;
    h|\?)
        show_help
        exit 0
        ;;
    H)  DO_HITL=1
        ;;
    q)  IP_QGC=$OPTARG
        ;;
    s)  serial=$OPTARG
        ;;
    v)  vehicle=$OPTARG
        ;;
    w)  world=$OPTARG
        ;;
    esac
done

if [ xunset = x"${vehicle}" ]; then
    if [ $DO_HITL -eq 0 ]; then
        vehicle=iris
    else
        vehicle=iris_hitl
    fi
fi

shift $((OPTIND-1))

# Checkout IP addresses if they have been set
for arg in $IP_QGC $IP_API 10.0.0.1; do
    if ! [[ ${arg} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: invalid IP: ${arg}!"
        echo ""
        show_help
        exit 1
    fi
done

# validate the vehicle count
if [ "${count}" -lt 1 -o "${count}" -gt 255 ]; then
    echo "Error: invalid vehicle count: ${count}!"
    echo ""
    show_help
    exit 1
fi


# check for 'secret' backdoor to the bash shell
if [ "$#" -gt 0 ]; then
    if [ "$1" = "bash" -o "$1" = "/bin/bash" ]; then
        exec /bin/bash
    fi

    show_help
    exit 1;
fi

if [ "${count}" -eq 1 ]; then
    Xvfb :99 -screen 0 1600x1200x24+32 &
    ${SITL_RTSP_PROXY}/build/sitl_rtsp_proxy &
fi

if [ "x${IP_API}" = "x" ]; then
    if [ "x${IP_QGC}" = "x" ]; then
        source ${WORKSPACE_DIR}/edit_rcS.bash
    else
        source ${WORKSPACE_DIR}/edit_rcS.bash -q ${IP_QGC}
    fi
elif [ "x${IP_QGC}" = "x" ]; then
    source ${WORKSPACE_DIR}/edit_rcS.bash -a ${IP_API}
else
    source ${WORKSPACE_DIR}/edit_rcS.bash -a ${IP_API} -q ${IP_QGC}
fi

if [ $? -eq 0 ]; then
    if [ "${count}" -gt 1 -o "${DO_HITL}" -eq 1 ]; then
        if [ "${DO_HITL}" -eq 1 ]; then
            cd ${FIRMWARE_DIR} &&
            HEADLESS=1 Tools/gazebo_hitl_multiple_run.sh -n $count -m $vehicle -w $world -b $baud -r $serial
        else
            cd ${FIRMWARE_DIR} &&
            HEADLESS=1 Tools/gazebo_sitl_multiple_run.sh -n $count -m $vehicle -w $world
        fi
    else
        cd ${FIRMWARE_DIR} &&
        HEADLESS=1 make px4_sitl gazebo_${vehicle}__${world}
    fi
else
    exit 1
fi
