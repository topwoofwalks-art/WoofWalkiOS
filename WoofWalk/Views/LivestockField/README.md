# Livestock Field UI Components

Complete iOS/SwiftUI port of Android livestock field UI components.

## Components Overview

### 1. LivestockFieldOverlay.swift
Map overlay rendering system for livestock field polygons.

**Features:**
- Renders polygons with color-coded fills based on confidence level
- Dynamic stroke width (4px selected, 2px normal)
- Species icons positioned intelligently within polygons
- Hazard warning indicators (red ring around icons)
- Point-in-polygon validation for icon placement
- Tap handling for field selection

**Color Scheme:**
- High Confidence: Green (#4CAF50)
- Medium Confidence: Amber (#FFC107)
- Low Confidence: Orange (#FF9800)
- No Livestock: Gray (#9E9E9E)
- Unknown: Brown (#8B4513)

**Code Sample:**
```swift
LivestockFieldOverlay(
    fields: viewModel.fields,
    selectedFieldId: selectedField?.fieldId,
    onFieldTap: { field in
        selectedField = field
        showFieldDetail = true
    }
)
```

### 2. FieldDetailSheet.swift
Bottom sheet displaying detailed field information and reporting interface.

**Features:**
- Field metadata display (confidence, area, species, reports)
- Last seen timestamp with relative formatting
- DynamicWorld land cover visualization
- Species selection interface
- Hazard marking toggle
- Notes input (300 char limit)
- Present/Not Present toggle
- Form validation

**Sections:**
- Header: Field information pills
- Info: Hazard warnings if applicable
- Report: Species selection and submission
- DynamicWorld: Land cover analysis with bar charts

**Code Sample:**
```swift
FieldDetailSheet(
    field: field,
    userLocation: userLocation,
    zoom: currentZoom,
    onDismiss: { showFieldDetail = false },
    onSubmitSignal: { fieldId, species, present, isDangerous, notes, photoUrl, location, zoom in
        viewModel.submitSignal(...)
    }
)
```

### 3. SpeciesSelector.swift
Multi-species selection component with hazard toggles.

**Features:**
- 5 species options (Cattle, Sheep, Horse, Deer, Other)
- Multi-select support
- Per-species hazard toggle
- Visual feedback (selected state, hazard indicators)
- Grid layout (3 columns)
- SF Symbols icons

**Species Icons:**
- Cattle: figure.walk
- Sheep: cloud.fill
- Horse: hare.fill
- Deer: leaf.fill
- Other: questionmark.circle.fill

**Code Sample:**
```swift
SpeciesSelector(
    selectedSpecies: $selectedSpecies,
    showHazardToggle: true
)
```

### 4. FieldDrawingMode.swift
Interactive polygon drawing interface for creating new fields.

**Features:**
- Tap-to-add vertices
- Real-time preview with minimap
- Undo last vertex
- Minimum 3 vertices validation
- Auto-close polygon on completion
- Drawing controls overlay
- Progress indicator (vertex count)
- Cancel with confirmation

**Controls:**
- Undo: Remove last vertex
- Cancel: Clear all vertices
- Complete: Validate and close polygon

**Code Sample:**
```swift
FieldDrawingMode(
    vertices: $drawingVertices,
    isDrawing: $isDrawingMode,
    onComplete: { polygon in
        newFieldPolygon = polygon
        showFieldForm = true
    },
    onCancel: {
        drawingVertices.removeAll()
    }
)
```

### 5. FieldFormSheet.swift
Form for creating new livestock fields with full metadata.

**Features:**
- Polygon preview with area calculation
- Species multi-select
- Hazard checkbox with description
- Notes field (300 char limit)
- Photo picker integration
- Field preview map
- Submission validation

**Sections:**
- Preview: Mini map with polygon overlay
- Species: Multi-select species picker
- Safety: Hazard marking checkbox
- Notes: Text editor with character count
- Photo: Optional photo upload

**Code Sample:**
```swift
FieldFormSheet(
    polygon: newFieldPolygon,
    userLocation: userLocation,
    zoom: currentZoom,
    onSubmit: { species, isDangerous, notes, photoUrl in
        viewModel.createField(...)
    }
)
```

### 6. LivestockModeToggleButton.swift
UI controls for livestock mode activation and field creation.

**Components:**
- `LivestockModeToggleButton`: Toggle button for enabling/disabling mode
- `LivestockFloatingButton`: Floating action button for field creation
- `LivestockToolbar`: Toolbar with draw, history, settings actions
- `ToolbarButton`: Reusable toolbar button component

**Code Sample:**
```swift
LivestockModeToggleButton(
    isEnabled: $livestockModeEnabled,
    onToggle: {
        if livestockModeEnabled {
            viewModel.loadFields(...)
        }
    }
)
```

## Integration Example

See `LivestockMapIntegration.swift` for complete integration example.

**Key Integration Points:**
1. Toggle livestock mode on/off
2. Display field overlays when mode is active
3. Handle field taps to show detail sheet
4. Enable drawing mode for creating new fields
5. Submit field signals and new fields to backend

## Model Requirements

**LivestockField** must have:
- `polygon: [CLLocationCoordinate2D]` - Computed from polygonRaw
- `confidenceLevel: ConfidenceLevel`
- `topSpecies: LivestockSpecies?`
- `isDangerous: Bool`
- `hasDynamicWorldData: Bool`
- `dwLivestockSuitability: Double`

**ConfidenceLevel** enum:
- `.unknown`, `.low`, `.medium`, `.high`, `.noLivestock`
- `displayName: String` property

**LivestockSpecies** enum:
- `.cattle`, `.sheep`, `.horse`, `.deer`, `.other`
- `displayName: String` property
- `iconName: String` property (SF Symbols)

## File Structure

```
WoofWalk/Views/LivestockField/
├── LivestockFieldOverlay.swift       # Map polygon rendering
├── FieldDetailSheet.swift            # Field detail view
├── SpeciesSelector.swift             # Species selection UI
├── FieldDrawingMode.swift            # Drawing interface
├── FieldFormSheet.swift              # New field form
├── LivestockModeToggleButton.swift   # Mode controls
├── LivestockMapIntegration.swift     # Integration example
└── README.md                         # This file
```

## Dependencies

- SwiftUI
- MapKit
- PhotosUI (for photo picker)
- Firebase Firestore (for GeoPoint)

## Usage Notes

1. **Map Integration**: Embed components within Map view
2. **State Management**: Use LivestockFieldViewModel for data
3. **User Location**: Required for field creation and signals
4. **Zoom Level**: Used for tile-based field loading
5. **Photo Upload**: Placeholder implementation, needs backend integration

## Testing Checklist

- [ ] Polygon rendering with correct colors
- [ ] Icon placement within polygon boundaries
- [ ] Field selection and detail sheet
- [ ] Drawing mode with vertex management
- [ ] Form validation (minimum 3 vertices)
- [ ] Species selection and hazard marking
- [ ] Notes character limit enforcement
- [ ] Photo picker integration
- [ ] Signal submission
- [ ] Field creation

## Performance Considerations

- Point-in-polygon calculations run on each icon position
- Large polygons (>100 vertices) may impact performance
- Icon count limited to 3 per field
- Fields filtered by viewport/zoom level before rendering
- Consider lazy loading for large field datasets
