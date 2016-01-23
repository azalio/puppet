#!/usr/bin/env bash
# Creates CloudFormation stack

# Load environment
# shellcheck disable=1090
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/../include/aws.sh"

command="$1"

case "$command" in
  install)
    pip install --user --upgrade awscli
    cd dist/profile || exit
    bundle install --without development system_tests --path vendor
    ;;
  script)
    cd dist/profile || exit
    bundle exec rake test
    ;;
  deploy)
    echo "Sync CloudFormation templates (${CFN_STACK_S3})"
    aws s3 sync "${APPDIR}/cfn/" "${CFN_STACK_S3}/" \
      --delete --acl public-read \
      --exclude "*" --include "*.json"

    echo 'Reset working directory'
    git stash --all

    echo "Creating TGZ archive (${CD_ARCHIVE_PATH})"
    tar cvzf "$CD_ARCHIVE_PATH" \
      --exclude-vcs \
      .

    echo "Uploading archive to S3 (${CD_S3_PATH})"
    aws s3 cp "${CD_ARCHIVE_PATH}" "${CD_S3_PATH}"

    aws_deploy_create_deployment \
      "$CD_APP_NAME" \
      "$CD_GROUP_NAME" \
      "$CD_BUCKET" \
      "$CD_KEY" \
      "$CD_ARCHIVE_BUNDLE" \
      "$CD_CONFIG"
    ;;
  *)
    echo "Unrecognized command ${command}" >&2; exit 1
    ;;
esac
