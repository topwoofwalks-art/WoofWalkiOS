#!/usr/bin/env ruby
# frozen_string_literal: true

# Ensures every Swift file under WoofWalk/ is a member of the WoofWalk target.
# Idempotent — safe to run on every CI invocation. Fixes the recurring iOS
# bug where a contributor adds a .swift file via the file system or
# git-only flow but never opens Xcode to add it to the target, then the
# Release build fails with "cannot find X in scope". Debug builds with the
# Headers / Compile Sources phases set to "auto-detect" mask this — but
# the target's Sources build phase only contains what's explicitly
# referenced in project.pbxproj.
#
# Run via `bundle exec ruby scripts/ensure_xcode_target_membership.rb`
# either locally or as a CI step before `fastlane beta`.

require "xcodeproj"
require "set"

PROJECT_PATH = "WoofWalk.xcodeproj"
TARGET_NAME = "WoofWalk"
SOURCE_ROOT = "WoofWalk" # directory containing the Swift sources

abort "Project not found at #{PROJECT_PATH} — run from repo root" unless Dir.exist?(PROJECT_PATH)

project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == TARGET_NAME }
abort "Target #{TARGET_NAME} not found" unless target

source_build_phase = target.source_build_phase

# Build a Set of canonical absolute paths already referenced by the
# Sources build phase. We use File.realpath on both sides of the
# comparison so that symlink-resolved paths on macOS (where /Users/runner
# is sometimes routed via /private/var) match the on-disk paths we glob.
# An earlier version of this script used Pathname#relative_path_from with
# Dir.pwd, which silently mismatched when xcodeproj's real_path returned
# a /private/-prefixed path while Dir.pwd did not — resulting in every
# file being detected as "missing" and added a second time.
existing_paths = Set.new
source_build_phase.files.each do |build_file|
  next unless build_file.file_ref
  abs = build_file.file_ref.real_path.to_s
  begin
    existing_paths << File.realpath(abs)
  rescue Errno::ENOENT
    # File referenced in pbxproj but not on disk — leave it, not our job.
    existing_paths << abs
  end
end

# Directories deliberately excluded from the iOS app build (commit
# 6ad2f32 "Exclude Database layer (SwiftData/iOS 17) and AppDependencies
# from build"). These contain parallel SwiftData implementations of
# files that ALSO live in the canonical Repositories/ folder — globbing
# them in would land same-basename .stringsdata outputs in the build
# and trip "Multiple commands produce" errors.
EXCLUDED_PATH_PREFIXES = %w[
  WoofWalk/Database
  WoofWalk/AppDependencies
].freeze

# Walk the source tree and find every .swift file not yet in the target.
missing = []
Dir.glob("#{SOURCE_ROOT}/**/*.swift").each do |path|
  normalised = path.tr("\\", "/")
  next if EXCLUDED_PATH_PREFIXES.any? { |prefix| normalised.start_with?(prefix + "/") }
  begin
    abs_path = File.realpath(path)
  rescue Errno::ENOENT
    next
  end
  next if existing_paths.include?(abs_path)
  missing << normalised
end

if missing.empty?
  puts "All Swift files already in #{TARGET_NAME} target membership. Nothing to do."
  exit 0
end

puts "Adding #{missing.size} missing file(s) to #{TARGET_NAME} target:"
missing.each { |m| puts "  - #{m}" }

# For each missing file, find or create its PBXFileReference under the
# project's main group (mirroring the on-disk folder structure), then
# add to the target's Sources build phase.
missing.each do |relpath|
  parts = relpath.split("/")
  filename = parts.last
  dir_parts = parts[0..-2] # e.g. ["WoofWalk", "Services"]

  # Resolve or create the group chain.
  group = project.main_group
  dir_parts.each do |segment|
    existing_group = group.groups.find { |g| g.display_name == segment || g.path == segment }
    if existing_group
      group = existing_group
    else
      group = group.new_group(segment, segment)
    end
  end

  # Create the file reference + add to target.
  file_ref = group.new_file(filename)
  target.add_file_references([file_ref])
end

project.save
puts "Project saved with #{missing.size} new file(s)."
