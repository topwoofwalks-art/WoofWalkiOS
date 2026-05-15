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

# Build a Set of paths already referenced by the Sources build phase. Each
# entry is the project-relative path of the file (e.g. WoofWalk/Foo.swift).
existing_paths = Set.new
source_build_phase.files.each do |build_file|
  next unless build_file.file_ref
  path = build_file.file_ref.real_path.to_s
  rel = Pathname.new(path).relative_path_from(Pathname.new(Dir.pwd)).to_s
  existing_paths << rel
end

# Walk the source tree and find every .swift file.
missing = []
Dir.glob("#{SOURCE_ROOT}/**/*.swift").each do |path|
  # Normalise to forward slashes (Windows checkout safety) — xcodeproj
  # is OS-agnostic but path comparisons must match.
  normalised = path.tr("\\", "/")
  next if existing_paths.any? { |existing| existing.tr("\\", "/") == normalised }
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
