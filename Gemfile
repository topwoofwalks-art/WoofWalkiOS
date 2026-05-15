source "https://rubygems.org"

gem "fastlane"

# Pinned to 1.15.2 (last 1.15.x release) to avoid the 1.16 regression
# in Pods-<target>-frameworks.sh that aborts with "source: unbound
# variable" under `set -u`. Patching the generated script (set +u)
# successfully bypasses the abort but causes the embed-frameworks
# rsync loop to hang for 60-90+ minutes. Cleanest fix is to use a
# CocoaPods that never had the bug.
# https://github.com/CocoaPods/CocoaPods/issues/12830
gem "cocoapods", "1.15.2"
