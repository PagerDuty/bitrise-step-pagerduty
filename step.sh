#!/bin/bash
set -ex

if [ ${api_version} == "v1" ]; then
    curl -X POST https://events.pagerduty.com/generic/2010-04-15/create_event.json -o v1-output.json -d @- << EOF
    {
        "service_key": "${integration_key}",
        "event_type": "trigger",
        "description": "${event_description}",
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

    CURL_RESULT=$?
    if test "$CURL_RESULT" != "0"; then
        echo "curl returned $CURL_RESULT"
        cat v1-output.json
        exit 1
    fi

    PD_STATUS=$(cat v1-output.json | jq '.status')
    if test "$PD_STATUS" != '"success"'; then
        echo "Event was not created."
        cat v1-output.json
        exit 1
    fi

    PD_MESSAGE=$(cat v1-output.json | jq '.message')
    PD_INCIDENT_KEY=$(cat v1-output.json | jq '.incident_key')
    envman add --key PAGERDUTY_EVENT_MESSAGE --value "$PD_MESSAGE"
    envman add --key PAGERDUTY_INCIDENT_KEY --value "$PD_INCIDENT_KEY"

elif [ ${api_version} == "v2" ]; then
    if [ "" == "${severity}" ]; then
        echo "Severity is required for Events API v2."
        exit 1
    fi

    curl -X POST https://events.pagerduty.com/v2/enqueue -o v2-output.json -d @- << EOF
    {
        "routing_key": "${integration_key}",
        "event_action": "trigger",
        "client": "Bitrise CI",
        "client_url": "${BITRISE_BUILD_URL}",
        "payload": {
            "summary": "${event_description}",
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

    CURL_RESULT=$?
    if test "$CURL_RESULT" != "0"; then
        echo "curl returned $CURL_RESULT"
        cat v2-output.json
        exit 1
    fi

    PD_STATUS=$(cat v2-output.json | jq '.status')
    if test "$PD_STATUS" != '"success"'; then
        echo "Event was not created."
        cat v2-output.json
        exit 1
    fi

    PD_MESSAGE=$(cat v2-output.json | jq '.message')
    PD_DEDUP_KEY=$(cat v2-output.json | jq '.dedup_key')
    envman add --key PAGERDUTY_EVENT_MESSAGE --value "$PD_MESSAGE"
    envman add --key PAGERDUTY_DEDUP_KEY --value "$PD_DEDUP_KEY"

else
    echo "Unknown API version ${api_version}"
    exit 1
fi
