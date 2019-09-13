#!/bin/bash
set -ex

if [ $BITRISE_BUILD_STATUS == "0" ] && [ ${skip_if_build_is_passing} == "true" ]; then
    echo "Build is passing... skipping PagerDuty event creation."
    exit 0
fi

if [ ${api_version} == "v1" ]; then
    curl -X POST https://events.pagerduty.com/generic/2010-04-15/create_event.json -d @- << EOF
    {
        "service_key": "${integration_key}",
        "event_type": "trigger",
        "description": "${description}",
        "client": "Bitrise CI",
        "client_url": "${BITRISE_BUILD_URL}",
        "details": {
            "workflow title": "${BITRISE_TRIGGERED_WORKFLOW_TITLE}",
            "git branch": "${BITRISE_GIT_BRANCH}",
            "git tag": "${BITRISE_GIT_TAG}",
            "git commit": "${BITRISE_GIT_COMMIT}"
        }
    }
EOF
elif [ ${api_version} == "v2" ]; then
    if [ "" == "${severity}" ]; then
        echo "Severity is required for Events API v2."
        exit 1
    fi

    curl -X POST https://events.pagerduty.com/v2/enqueue -d @- << EOF
    {
        "routing_key": "${integration_key}",
        "event_action": "trigger",
        "client": "Bitrise CI",
        "client_url": "${BITRISE_BUILD_URL}",
        "payload": {
            "summary": "${description}",
            "source": "${BITRISE_BUILD_URL}",
            "severity": "${severity}",
            "custom_details": {
                "workflow title": "${BITRISE_TRIGGERED_WORKFLOW_TITLE}",
                "git branch": "${BITRISE_GIT_BRANCH}",
                "git tag": "${BITRISE_GIT_TAG}",
                "git commit": "${BITRISE_GIT_COMMIT}"
            }
        }
    }
EOF
else
    echo "Unknown API version ${api_version}"
    exit 1
fi

set | grep BITRISE

#
# --- Export Environment Variables for other Steps:
# You can export Environment Variables for other Steps with
#  envman, which is automatically installed by `bitrise setup`.
# A very simple example:
envman add --key EXAMPLE_STEP_OUTPUT --value 'the value you want to share'
# Envman can handle piped inputs, which is useful if the text you want to
# share is complex and you don't want to deal with proper bash escaping:
#  cat file_with_complex_input | envman add --KEY EXAMPLE_STEP_OUTPUT
# You can find more usage examples on envman's GitHub page
#  at: https://github.com/bitrise-io/envman

#
# --- Exit codes:
# The exit code of your Step is very important. If you return
#  with a 0 exit code `bitrise` will register your Step as "successful".
# Any non zero exit code will be registered as "failed" by `bitrise`.
