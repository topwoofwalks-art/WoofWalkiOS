# WoofWalk iOS Testing Guide

## Overview

Comprehensive testing infrastructure for WoofWalk iOS application with XCTest, XCUITest, and CI/CD integration.

## Test Structure

```
WoofWalkTests/
├── Mocks/                      # Mock implementations
│   ├── MockLocationService.swift
│   ├── MockAuthService.swift
│   ├── MockWalkRepository.swift
│   └── MockPoiRepository.swift
├── Helpers/                    # Test utilities
│   ├── TestDataBuilder.swift
│   ├── XCTestCase+Async.swift
│   └── AssertionHelpers.swift
├── Repository/                 # Repository tests
│   ├── WalkRepositoryTests.swift
│   └── PoiRepositoryTests.swift
├── ViewModels/                 # ViewModel tests
│   ├── AuthViewModelTests.swift
│   └── MapViewModelTests.swift
├── Services/                   # Service tests
│   └── AuthServiceTests.swift
├── Utils/                      # Utility tests
│   └── GeoHashUtilTests.swift
├── Integration/                # Integration tests
│   ├── DatabaseIntegrationTests.swift
│   └── LocationServiceIntegrationTests.swift
└── Performance/                # Performance tests
    └── WalkRepositoryPerformanceTests.swift

WoofWalkUITests/
├── WalkTrackingUITests.swift
├── NavigationUITests.swift
├── POIManagementUITests.swift
└── ProfileManagementUITests.swift
```

## Running Tests

### Local Testing

```bash
# Run all tests
fastlane test_all

# Run unit tests only
fastlane test

# Run UI tests only
fastlane ui_test

# Run specific test class
xcodebuild test -scheme WoofWalk -only-testing:WoofWalkTests/WalkRepositoryTests

# Run specific test method
xcodebuild test -scheme WoofWalk -only-testing:WoofWalkTests/WalkRepositoryTests/testInsertWalk
```

### Using Xcode

1. Open `WoofWalk.xcworkspace`
2. Press `Cmd + U` to run all tests
3. Use Test Navigator (`Cmd + 6`) to run individual tests
4. View test results in Test Navigator

### CI/CD

Tests run automatically on:
- Push to `main` or `develop` branches
- Pull requests
- Nightly at 2 AM UTC

## Test Coverage

### Current Coverage

```
Unit Tests:        45+ test cases
UI Tests:          20+ test scenarios
Integration Tests: 10+ test cases
Performance Tests: 5+ benchmarks
```

### Coverage Reports

```bash
# Generate coverage report
fastlane test_all

# View HTML report
open fastlane/test_output/coverage/index.html

# Check coverage percentage
slather coverage --scheme WoofWalk WoofWalk.xcodeproj
```

## Mock Services

### MockLocationService

```swift
let mockLocationService = MockLocationService()
mockLocationService.simulateLocation(CLLocation(...))
mockLocationService.simulateAuthorizationChange(.authorizedWhenInUse)
```

### MockAuthService

```swift
let mockAuthService = MockAuthService()
mockAuthService.shouldSucceed = true
try await mockAuthService.signIn(email: "test@example.com", password: "test123")
```

### MockWalkRepository

```swift
let mockRepository = MockWalkRepository()
try mockRepository.insert(walk)
XCTAssertTrue(mockRepository.insertCalled)
```

## Test Data Builders

```swift
// Create test user
let user = TestDataBuilder.createTestUser()

// Create test walk
let walk = TestDataBuilder.createTestWalk(
    id: "walk-123",
    distanceMeters: 5000,
    durationSec: 3600
)

// Create test POI
let poi = TestDataBuilder.createTestPOI(
    type: .bin,
    coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
)

// Create test location
let location = TestDataBuilder.createTestLocation()
```

## Async Testing Helpers

```swift
// Test async functions
asyncTest {
    try await viewModel.signIn(email: "test@example.com", password: "test123")
}

// Assert async errors
await XCTAssertThrowsErrorAsync(
    try await repository.insert(invalidWalk)
)

// Wait for publisher
try awaitPublisher(authService.currentUserPublisher, timeout: 1.0)
```

## Custom Assertions

```swift
// Coordinate equality
XCTAssertCoordinateEqual(coord1, coord2, accuracy: 0.0001)

// Distance assertions
XCTAssertDistance(from: start, to: end, isGreaterThan: 100)
XCTAssertDistance(from: start, to: end, isLessThan: 200)
```

## UI Testing Best Practices

### Accessibility Identifiers

```swift
// Add in view code
.accessibilityIdentifier("startWalkButton")

// Use in tests
app.buttons["startWalkButton"].tap()
```

### Launch Arguments

```swift
app.launchArguments = ["UI-Testing", "Reset-Onboarding"]
app.launch()
```

### Waiting for Elements

```swift
let button = app.buttons["Start Walk"]
XCTAssertTrue(button.waitForExistence(timeout: 5))
```

## Performance Testing

```swift
func testInsertPerformance() {
    measure {
        // Code to benchmark
        try? repository.insert(walk)
    }
}
```

### Performance Baselines

1. Run test once
2. Editor → Set Baseline
3. Future runs compare against baseline

## Integration Tests

### Database Integration

```swift
@MainActor
func testDatabaseOperations() throws {
    let container = try ModelContainer(...)
    let context = ModelContext(container)
    let repository = WalkRepository(modelContext: context)

    // Test actual database operations
}
```

### Location Services

```swift
func testLocationTracking() {
    let mockService = MockLocationService()
    mockService.startTracking()
    mockService.simulateLocation(location)
    // Verify behavior
}
```

## Continuous Integration

### GitHub Actions Workflows

**ios-ci.yml** - Main CI pipeline
- Linting with SwiftLint
- Unit tests
- UI tests
- Build verification
- Code quality checks

**coverage.yml** - Coverage reporting
- Generate coverage reports
- Upload to Codecov
- Comment on PRs

**nightly-tests.yml** - Comprehensive testing
- Test on multiple devices
- Performance tests
- Scheduled nightly runs

### CI Configuration

```yaml
# Required secrets
APPLE_ID
TEAM_ID
ITC_TEAM_ID
CODECOV_TOKEN

# Environment variables
XCODE_VERSION: '15.2'
```

## Fastlane Configuration

### Available Lanes

```bash
fastlane test           # Unit tests
fastlane ui_test        # UI tests
fastlane test_all       # All tests + coverage
fastlane lint           # SwiftLint
fastlane build_for_testing
fastlane screenshots
fastlane beta           # TestFlight upload
fastlane release        # App Store build
```

### Configuration Files

- `Fastfile` - Lane definitions
- `Appfile` - App configuration
- `Gemfile` - Ruby dependencies
- `.swiftlint.yml` - Linting rules
- `.slather.yml` - Coverage settings

## Troubleshooting

### Tests Not Running

```bash
# Clean build
fastlane clean_build

# Reset simulator
xcrun simctl erase all

# Reinstall dependencies
pod deintegrate
pod install
```

### Coverage Not Generated

```bash
# Ensure code coverage is enabled in scheme
# Edit Scheme → Test → Options → Code Coverage

# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData
```

### UI Tests Failing

```bash
# Reset UI test state
defaults delete com.apple.iphonesimulator

# Increase timeouts
let element = app.buttons["button"]
XCTAssertTrue(element.waitForExistence(timeout: 10))
```

## Best Practices

### Unit Tests

1. Test one thing per test
2. Use descriptive test names
3. Arrange-Act-Assert pattern
4. Mock external dependencies
5. Test edge cases

### UI Tests

1. Use accessibility identifiers
2. Wait for elements to exist
3. Test user flows, not implementation
4. Keep tests independent
5. Use page objects for reusability

### Performance Tests

1. Set realistic baselines
2. Test on actual devices
3. Profile before optimizing
4. Document performance requirements
5. Monitor regressions

### Code Coverage

1. Target 80%+ coverage
2. Focus on critical paths
3. Don't chase 100% blindly
4. Test business logic thoroughly
5. Review coverage reports regularly

## Resources

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [XCUITest Guide](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode/)
- [Fastlane Documentation](https://docs.fastlane.tools/)
- [SwiftLint Rules](https://realm.github.io/SwiftLint/rule-directory.html)
