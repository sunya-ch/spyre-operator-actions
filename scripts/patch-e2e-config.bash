#!/bin/bash
# +-------------------------------------------------------------------+
# | (C) Copyright IBM Corp. 2025, 2026                                |
# | SPDX-License-Identifier: Apache-2.0                               |
# +-------------------------------------------------------------------+
set -e -o pipefail
readonly TEST_CONFIG=test/config.yaml

# Detect yq version and set appropriate command
YQ_VERSION=$(yq --version 2>&1 | grep -oE '[0-9]+' | head -n1)
if [[ "$YQ_VERSION" -eq 4 ]]; then
	# Version 4 syntax: eval is default, -i for in-place
	YQ_CMD="yq -i"
else
	# Version 3 syntax: requires 'eval' or 'write'
	YQ_CMD="yq eval -i"
fi

function patch_test_config() {
	if [[ -n ${HAS_DEVICE} ]]; then
		echo "updating HAS_DEVICE to ${HAS_DEVICE}"
		${YQ_CMD} '.hasDevice=(strenv(HAS_DEVICE) == "true")' ${TEST_CONFIG}
	fi

	if [[ -n ${WORKLOAD_IMAGE} ]]; then
		echo "updating WORKLOAD_IMAGE to ${WORKLOAD_IMAGE}"
		${YQ_CMD} '.workloadImage=strenv(WORKLOAD_IMAGE)' ${TEST_CONFIG}
	fi

	if [[ -n ${NODE_NAME} ]]; then
		${YQ_CMD} '.nodeName=strenv(NODE_NAME)' ${TEST_CONFIG}
	fi

	if [[ -n ${PSEUDO_DEVICE_MODE} ]]; then
		echo "updating PSEUDO_DEVICE_MODE to ${PSEUDO_DEVICE_MODE}"
		${YQ_CMD} '.pseudoDeviceMode = (strenv(PSEUDO_DEVICE_MODE) == "true")' ${TEST_CONFIG}
	fi

	if [[ -n ${OPERATOR_CHANNEL} ]]; then
		${YQ_CMD} '.defaultChannel=strenv(OPERATOR_CHANNEL)' ${TEST_CONFIG}
	fi

	# Publicly-available tag patch

	if [[ -n ${OPERATOR_TAG} ]]; then
		${YQ_CMD} '.operator.version=strenv(OPERATOR_TAG)' ${TEST_CONFIG}
		${YQ_CMD} '.catalog.version=strenv(OPERATOR_TAG)' ${TEST_CONFIG}
		${YQ_CMD} '.bundle.version=strenv(OPERATOR_TAG)' ${TEST_CONFIG}
	fi

	if [[ -n ${DEVICE_PLUGIN_TAG} ]]; then
		${YQ_CMD} '.devicePlugin.version=strenv(DEVICE_PLUGIN_TAG)' ${TEST_CONFIG}
	fi

	if [[ -n ${SCHEDULER_PLUGIN_TAG} ]]; then
		${YQ_CMD} '.scheduler.version=strenv(SCHEDULER_PLUGIN_TAG)' ${TEST_CONFIG}
	fi

	if [[ -n ${VALIDATOR_TAG} ]]; then
		${YQ_CMD} '.podValidator.version=strenv(VALIDATOR_TAG)' ${TEST_CONFIG}
	fi

	if [[ -n ${HEALTH_CHECKER_TAG} ]]; then
		${YQ_CMD} '.healthChecker.version=strenv(HEALTH_CHECKER_TAG)' ${TEST_CONFIG}
	fi

	if [[ -n ${DRA_DRIVER_TAG} ]]; then
		${YQ_CMD} '.draDriver.version=strenv(DRA_DRIVER_TAG)' ${TEST_CONFIG}
	fi

	# Publicly-unavailable tag patch

	if [[ -n ${DEVICE_PLUGIN_INIT_TAG} ]]; then
		${YQ} eval -i '.devicePluginInit.version=strenv(DEVICE_PLUGIN_INIT_TAG)' ${TEST_CONFIG}
	fi

	if [[ -n ${EXPORTER_TAG} ]]; then
		${YQ} eval -i '.exporter.version=strenv(EXPORTER_TAG)' ${TEST_CONFIG}
		${YQ} eval -i '.mockUser.version=strenv(EXPORTER_TAG)' ${TEST_CONFIG}
	fi

	if [[ -n ${CARD_MGMT_TAG} ]]; then
		${YQ} eval -i '.cardManagement.version=strenv(CARD_MGMT_TAG)' ${TEST_CONFIG}
	fi

	if [[ -n ${CARD_MGMT_RUNNER_IMAGE} ]]; then
		${YQ} eval -i '.cardManagement.config.pfRunnerImage=strenv(CARD_MGMT_RUNNER_IMAGE)' ${TEST_CONFIG}
		${YQ} eval -i '.cardManagement.config.vfRunnerImage=strenv(CARD_MGMT_RUNNER_IMAGE)' ${TEST_CONFIG}
	fi

	if [[ -n ${SPYRE_FILTER} ]]; then
		${YQ} eval -i '.cardManagement.config.spyreFilter=strenv(SPYRE_FILTER)' ${TEST_CONFIG}
	fi

	# Registry patch

	if [[ -n ${REGISTRY} ]]; then
		echo "Replacing docker.io/spyre-operator with ${REGISTRY}"
		# Replace docker.io/spyre-operator with REGISTRY in all image references
		${YQ_CMD} '(.. | select(type == "!!str" and (. == "*docker.io/spyre-operator*"))) |= sub("docker.io/spyre-operator", strenv(REGISTRY))' ${TEST_CONFIG}
	fi

	if [[ -n ${TEST_REPO} ]] && [[ -n ${TEST_REGISTRY} ]] && [[ -n ${TEST_TAG} ]]; then
		echo "Mapping TEST_REPO ${TEST_REPO} to component and setting registry to ${TEST_REGISTRY}"

		# Map repository name to component name
		case "${TEST_REPO}" in
			"spyre-operator")
				COMPONENT="operator"
				;;
			"spyre-device-plugin")
				COMPONENT="devicePlugin"
				;;
			"spyre-scheduler-plugins")
				COMPONENT="scheduler"
				;;
			"spyre-webhook-validator")
				COMPONENT="podValidator"
				;;
			"spyre-health-checker")
				COMPONENT="healthChecker"
				;;
			"dra-driver-spyre")
				COMPONENT="draDriver"
				;;
			*)
				echo "Warning: Unknown repository ${TEST_REPO}, skipping registry update"
				COMPONENT=""
				;;
		esac

		# Set the registry for the mapped component
		if [[ -n ${COMPONENT} ]]; then
			if [[ ${COMPONENT} == "scheduler" ]] && [[ -n ${TEST_SECONDARY_SCHED_REGISTRY} ]] ; then
				echo "Setting .${COMPONENT}.repository to ${TEST_SECONDARY_SCHED_REGISTRY} and tag to ${TEST_TAG}"
				${YQ_CMD} ".${COMPONENT}.repository=strenv(TEST_SECONDARY_SCHED_REGISTRY)" ${TEST_CONFIG}
				${YQ_CMD} ".${COMPONENT}.version=strenv(TEST_TAG)" ${TEST_CONFIG}
				${YQ_CMD} ".${COMPONENT}.imagePullPolicy=\"IfNotPresent\"" ${TEST_CONFIG}
			else
				echo "Setting .${COMPONENT}.repository to ${TEST_REGISTRY} and tag to ${TEST_TAG}"
				${YQ_CMD} ".${COMPONENT}.repository=strenv(TEST_REGISTRY)" ${TEST_CONFIG}
				${YQ_CMD} ".${COMPONENT}.version=strenv(TEST_TAG)" ${TEST_CONFIG}
				${YQ_CMD} ".${COMPONENT}.imagePullPolicy=\"IfNotPresent\"" ${TEST_CONFIG}
			fi

			# If component is operator, also set catalog and bundle registry
			if [[ ${COMPONENT} == "operator" ]] && [[ -n ${TEST_CATALOG_REGISTRY} ]] ; then
				echo "Setting .catalog"
				${YQ_CMD} ".catalog.repository=strenv(TEST_CATALOG_REGISTRY)" ${TEST_CONFIG}
				${YQ_CMD} ".catalog.version=strenv(TEST_TAG)" ${TEST_CONFIG}
				${YQ_CMD} ".catalog.imagePullPolicy=\"IfNotPresent\"" ${TEST_CONFIG}
				echo "Setting .bundle"
				${YQ_CMD} ".bundle.repository=strenv(TEST_CATALOG_REGISTRY)" ${TEST_CONFIG}
				${YQ_CMD} ".bundle.version=strenv(TEST_TAG)" ${TEST_CONFIG}
				${YQ_CMD} ".bundle.imagePullPolicy=\"IfNotPresent\"" ${TEST_CONFIG}
			fi
		fi
	fi
	return
}

patch_test_config
