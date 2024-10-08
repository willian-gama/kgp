#!/bin/bash

# FOR GITHUB ACTIONS, HOWEVER WHEN PUSHING A NEW CHANGE IT DOES NOT RE-TRIGGER ALL PRS CHECKS
FILE="build.gradle.kts"

get_version_number() {
  local content="$1"
  if [[ "$content" =~ version\ *=\ *\"([0-9]+\.[0-9]+\.[0-9]+)\" ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  else
    return 1
  fi
}

compare_versions() {
  local local_version=$1
  local remote_version=$2

  IFS="." read -r local_major local_minor local_patch <<<"$local_version"
  IFS="." read -r remote_major remote_minor remote_patch <<<"$remote_version"

  # compare major versions
  if [ "$remote_major" -gt "$local_major" ]; then
    echo "local major version is lower than remote version"
    return 0
  elif [ "$remote_major" -lt "$local_major" ]; then
    echo "local version: $local_version is greater than remote version: $remote_version"
    return 1
  fi

  # compare minor versions
  if [ "$remote_minor" -gt "$local_minor" ]; then
    echo "local minor version is lower than remote version"
    return 0
  elif [ "$remote_minor" -lt "$local_minor" ]; then
    echo "local version: $local_version is greater than remote version: $remote_version"
    return 1
  fi

  # compare patch versions
  if [ "$remote_patch" -ge "$local_patch" ]; then
    echo "remote patch version is greater than or equal to local version"
    return 0
  else
    echo "local version: $local_version is greater than remote version: $remote_version"
    return 1
  fi
}

bump_and_push_new_version_to_git() {
  local_version=$1
  remote_version=$2

  IFS='.' read -r major minor patch <<< "$remote_version"
  new_local_version="$major.$minor.$((patch + 1))"
  perl -i -pe "s/$local_version/$new_local_version/" "$FILE"

  commit_message="auto bump version from $local_version to $new_local_version"
  echo "$commit_message"

  # https://github.com/actions/checkout/blob/main/README.md#push-a-commit-using-the-built-in-token
  git config user.name "renovate[bot]"
  git config user.email "29139614+renovate[bot]@users.noreply.github.com"
  git config --add --bool push.autoSetupRemote true # create a new branch automatically

  git add "$FILE"
  git commit -m "$commit_message"
  git push
}

bump_version_if_needed() {
  git pull
  local_file_content="$(cat "$FILE")"
  if [ -z "$local_file_content" ]; then
    echo "Local $FILE could not be found or is empty."
    return 1
  fi

  git fetch origin develop
  remote_file_content="$(git show origin/develop:"$FILE")"
  if [ -z "$remote_file_content" ]; then
    echo "Remote $FILE could not be found or is empty."
    return 1
  fi

  if ! local_version=$(get_version_number "$local_file_content"); then
    echo "Error when getting local version."
    return 1
  fi

  if ! remote_version=$(get_version_number "$remote_file_content"); then
    echo "Error when getting remote version."
    return 1
  fi

  if compare_versions "$local_version" "$remote_version" -eq 0; then
    bump_and_push_new_version_to_git "$local_version" "$remote_version"
  fi
}

bump_version_if_needed