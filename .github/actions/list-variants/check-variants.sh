#!/bin/bash
#
# Collects repo path information to determine what is part of a variant, then
# compares the changed files from the PR to the paths to see which variants are
# actually affected by the changes.
#
# Expects get-changed-files to have been run first with json content of modified
# files in ${HOME}/files.json.

function usage {
    echo "Usage: $0 <filter> <token>"
    echo
    echo -e "\tfilter: boolean indicating whether to return all variants (false) or only those affected by changes"
    echo -e "\ttoken:  GitHub token with rights to query for commit information"
    echo
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

filter="$1"
token=""

if [[ $# -eq 2 ]]; then
    token="$2"
fi

CHANGED_FILES="/tmp/files.txt"
OUTPUT="/tmp/ghoutput"
REPO_ROOT=$(git rev-parse  --show-toplevel)

# Parse the changed file data into something easy for us to parse
jq -r .[] "${HOME}/files.json" > "${CHANGED_FILES}"

# Make sure there are no leftover artifacts
rm "${OUTPUT}"

cd "${REPO_ROOT}"
cd variants

output="$(ls -d */ | cut -d'/' -f 1 | grep -vE '^(shared|target)$')"
aarch="aarch-enemies=$(ls -d */ | cut -d'/' -f 1 | grep -E '(^(metal|vmware)|\-dev$)' | jq -R -s -c 'split("\n")[:-1] | [ .[] | {"variant": ., "arch": "aarch64"}]')"
echo $aarch
echo ${aarch@Q} >> $OUTPUT

cd ..

if [[ "${filter}" != "false" ]]; then
    # Check if any of the changed files are under relevant paths for our variants
    variants=()

    # Use something like buildsys to emit files for each variant
    mkdir -p /tmp/variant-info
    for variant in ${output}; do
        echo "variants/${variant}" > /tmp/variant-info/${variant}
        echo "packages/foo" >> /tmp/variant-info/${variant}
    done

    # Add the readme to one variant as a test
    echo "README.md" >> /tmp/variant-info/aws-k8s-1.28

    for variant in ${output}; do
        while read line; do
            if [[ -n $(grep -e ^${line} ${CHANGED_FILES}) ]]; then
              # There are changed files under this path
              variants+="${variant}"
              break
            fi
        done <"/tmp/variant-info/${variant}"
    done
    output=$(IFS=, ; echo "variants=[${variants[*]}]")
else
    cd variants
    output="variants=$(ls -d */ | cut -d'/' -f 1 | grep -vE '^(shared|target)$' | jq -R -s -c 'split("\n")[:-1]')"
fi

echo $output
echo ${output@Q} >> $OUTPUT
