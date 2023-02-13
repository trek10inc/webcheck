#!/bin/bash

# Caveats:
# - This script expect the response to be in JSON format
# - This script will exit when FAILURE_LIMIT has been reached

# how frequently (in seconds) do we run a check
# INTERVAL=2
[[ -z ${INTERVAL} ]] && echo "Error: INTERVAL not set. Exiting..." && exit 1

# number of checks to run. if set to value greater than 0, DURATION is ignored
# COUNT=0
[[ -z ${COUNT} ]] && COUNT=0

# set max duration to limit script to a specific duration if COUNT is used
[[ ${COUNT} -gt 0 && -z ${MAX_DURATION} ]] && echo "Error: COUNT is set but MAX_DURATION is not. Exiting..." && exit 1

# how long (in seconds) does the job run?
# DURATION=10
[[ -z ${DURATION} && ${COUNT} -eq 0 ]] && echo "Error: DURATION not set. Exiting..." && exit 1

# how many failures can we tolerate?
# FAILURE_LIMIT=3
[[ -z ${FAILURE_LIMIT} ]] && echo "Error: FAILURE_LIMIT not set. Exiting..." && exit 1

# url to test
# URL='http://192.168.0.161:30090/healthz'
[[ -z ${URL} ]] && echo "Error: URL not set. Exiting..." && exit 1

# jq string to parse response with
# JQ_PARSER=".status"
[[ -z ${JQ_PARSER} ]] && echo "Error: JQ_PARSER not set. Exiting..." && exit 1

# expected response
# EXPECTED_RESPONSE="ok"
[[ -z ${EXPECTED_RESPONSE} ]] && echo "Error: EXPECTED_RESPONSE not set. Exiting..." && exit 1

# max time in seconds the entire request can take
# TIMEOUT=3
[[ -z ${TIMEOUT} ]] && TIMEOUT=5

# set to an integer greater than or equal to 1 to enable
[[ -z ${DEBUG} ]] && DEBUG=0

# temp file to capture response
BODY_FILE="/tmp/tmp.$$.1.html"

# need these to maintain state
FAILED=0
SUCCEEDED=0
START_TIME=$(date +'%s')

if [[ $COUNT -gt 0 ]]; then
    [[ ${DEBUG} -ge 1 ]] && echo "Info: Making ${COUNT} observations."

    for((i=0; $i < $COUNT; i++)); do
        CURRENT_TIME=$(date +'%s')
        TIME_ELAPSED=$((CURRENT_TIME - START_TIME))

        # break if we've run to max duration
        if [[ ${TIME_ELAPSED} -ge ${MAX_DURATION} ]]; then
            [[ ${DEBUG} -ge 1 ]] && echo -e "Info: Execution time has reached max duration of ${MAX_DURATION} seconds\n\nExiting..."
            break
        fi

        STATUS_CODE=$(curl -m ${TIMEOUT} -Ls -w "%{http_code}" -o ${BODY_FILE} "${URL}")

        if [[ ${STATUS_CODE} == '000' || ${STATUS_CODE} -ge 400 ]]; then
            [[ ${DEBUG} -ge 1 ]] && echo "Error: Bad status code ${STATUS_CODE}"
            FAILED=$((FAILED + 1))
        else
            BODY=$(cat ${BODY_FILE})

            if [[ ! -z ${BODY} ]]; then
                [[ ${DEBUG} -ge 1 ]] && echo -e "---------------------Response Body---------------------\n${BODY}\n"
                RESULT=$(echo ${BODY} | jq -rM "${JQ_PARSER}" 2>/dev/null)
                [[ ${DEBUG} -ge 1 ]] && echo "Info: Result = ${RESULT}"

                if [[ $? -ne 0 || ${RESULT} != "${EXPECTED_RESPONSE}" ]]; then
                    [[ ${DEBUG} -ge 1 ]] && echo "Error: Unexpected result observed"
                    FAILED=$((FAILED + 1))
                else
                    [[ ${DEBUG} -ge 1 ]] && echo "Info: Expected result observed"
                    SUCCEEDED=$((SUCCEEDED + 1))
                fi
            else
                [[ ${DEBUG} -ge 1 ]] && echo "Error: No response body"
                FAILED=$((FAILED + 1))
            fi
        fi

        if [[ ${FAILED} -ge ${FAILURE_LIMIT} ]]; then
            [[ ${DEBUG} -ge 1 ]] && echo -e "Error: Observed ${FAILURE_LIMIT} failures\n\nExiting..."
            echo "{ \"Succeeded\": ${SUCCEEDED}, \"Failed\": ${FAILED} }"
            exit 1
        fi

        [[ ${DEBUG} -ge 1 ]] && echo "Info: Succeeded (${SUCCEEDED}) Failed(${FAILED})"

        sleep $INTERVAL    

    done

    echo "{ \"Succeeded\": ${SUCCEEDED}, \"Failed\": ${FAILED} }"

    if [[ ${SUCCEEDED} -eq 0 ]]; then
        [[ ${DEBUG} -ge 1 ]] && echo -e "Error: No successful responses were observed"
        exit 1
    else
        exit 0
    fi
else
    [[ $((DURATION % INTERVAL)) -ne 0 ]] && echo "Error: DURATION must be evenly divisible by INTERVAL" && exit 1

    OBSERVATIONS=$((${DURATION} / ${INTERVAL}))
    [[ ${DEBUG} -ge 1 ]] && echo "Info: Running for ${DURATION} seconds making ${OBSERVATIONS} observations"

    while true; do
        CURRENT_TIME=$(date +'%s')
        TIME_ELAPSED=$((CURRENT_TIME - START_TIME))

        # break if we've run to full duration
        if [[ ${TIME_ELAPSED} -ge ${DURATION} ]]; then
            [[ ${DEBUG} -ge 1 ]] && echo -e "Info: Execution time has reached ${DURATION} seconds\n\nExiting..."
            break
        fi

        STATUS_CODE=$(curl -m ${TIMEOUT} -Ls -w "%{http_code}" -o ${BODY_FILE} "${URL}")

        if [[ ${STATUS_CODE} == '000' || ${STATUS_CODE} -ge 400 ]]; then
            [[ ${DEBUG} -ge 1 ]] && echo "Error: Bad status code ${STATUS_CODE}"
            FAILED=$((FAILED + 1))
        else
            BODY=$(cat ${BODY_FILE})

            if [[ ! -z ${BODY} ]]; then
                [[ ${DEBUG} -ge 1 ]] && echo -e "---------------------Response Body---------------------\n${BODY}\n"
                RESULT=$(echo ${BODY} | jq -rM "${JQ_PARSER}" 2>/dev/null)
                [[ ${DEBUG} -ge 1 ]] && echo "Info: Result = ${RESULT}"

                if [[ $? -ne 0 || ${RESULT} != "${EXPECTED_RESPONSE}" ]]; then
                    [[ ${DEBUG} -ge 1 ]] && echo "Error: Unexpected result observed"
                    FAILED=$((FAILED + 1))
                else
                    [[ ${DEBUG} -ge 1 ]] && echo "Info: Expected result observed"
                    SUCCEEDED=$((SUCCEEDED + 1))
                fi
            else
                [[ ${DEBUG} -ge 1 ]] && echo "Error: No response body"
                FAILED=$((FAILED + 1))
            fi
        fi

        if [[ ${FAILED} -ge ${FAILURE_LIMIT} ]]; then
            [[ ${DEBUG} -ge 1 ]] && echo -e "Error: Observed ${FAILURE_LIMIT} failures\n\nExiting..."
            echo "{ \"Succeeded\": ${SUCCEEDED}, \"Failed\": ${FAILED} }"
            exit 1
        fi

        [[ ${DEBUG} -ge 1 ]] && echo "Info: Succeeded (${SUCCEEDED}) Failed(${FAILED})"

        sleep $INTERVAL    
    done

    echo "{ \"Succeeded\": ${SUCCEEDED}, \"Failed\": ${FAILED} }"
    
    if [[ ${SUCCEEDED} -eq 0 ]]; then
        [[ ${DEBUG} -ge 1 ]] && echo -e "Error: No successful responses were observed"
        exit 1
    else
        exit 0
    fi
fi
