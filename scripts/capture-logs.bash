#!/bin/bash
# +-------------------------------------------------------------------+
# | (C) Copyright IBM Corp. 2025, 2026                                |
# | SPDX-License-Identifier: Apache-2.0                               |
# +-------------------------------------------------------------------+

#!/bin/bash
readonly POD_NAME=${1}
readonly NAMESPACE=${2}
readonly BARRIER_FILE=${3}

function usage() {
	echo "Usage: capture-logs.bash <pod_name> <namespace> <barrier_file_name>"
	exit 2
	return
}

if [[ "x" == "x${POD_NAME}" ]]; then
	echo "pod name is required"
	usage
fi

if [[ "x" == "x${NAMESPACE}" ]]; then
	echo "name space required"
	usage
fi

if [[ "x" == "x${BARRIER_FILE}" ]]; then
	echo "barrier file is required"
	usage
fi

trap 'kill $(jobs -p) 2>/dev/null || true' EXIT
if [[ -f ${BARRIER_FILE} ]]; then
	stern ${POD_NAME} -n ${NAMESPACE} &
	STERN_PID=${!}
fi

while [[ -f ${BARRIER_FILE} ]]; do
	sleep 30s
done

if [[ -n ${STERN_PID} ]]; then
	echo "Barrier file removed, kill stern process =${STERN_PID}"
	kill -9 ${STERN_PID}
fi
exit 0
