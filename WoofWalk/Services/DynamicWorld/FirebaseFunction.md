# Firebase Cloud Function - Dynamic World Integration

This document outlines the required Firebase Cloud Function for Google Earth Engine integration.

## Function: enrichFieldsWithDynamicWorld

### Location
`functions/src/dynamicWorld.ts`

### Purpose
Query Google Earth Engine Dynamic World dataset for land cover probabilities and calculate livestock suitability scores.

## Implementation

```typescript
import * as functions from 'firebase-functions';
import * as ee from '@google/earthengine';

interface FieldLocation {
  fieldId: string;
  lat: number;
  lng: number;
  bbox?: number[];
}

interface DateRange {
  start: string;
  end: string;
}

interface RequestData {
  fields: FieldLocation[];
  dateRange?: DateRange;
}

ee.initialize(null, null, () => {
  console.log('Earth Engine initialized');
}, (error: Error) => {
  console.error('Earth Engine initialization failed:', error);
});

export const enrichFieldsWithDynamicWorld = functions.https.onCall(
  async (data: RequestData, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const { fields, dateRange } = data;

    if (!fields || fields.length === 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Fields array is required'
      );
    }

    try {
      const enrichedFields = await Promise.all(
        fields.map(field => enrichSingleField(field, dateRange))
      );

      return {
        success: true,
        fields: enrichedFields,
        count: enrichedFields.length
      };
    } catch (error) {
      console.error('Enrichment error:', error);
      throw new functions.https.HttpsError(
        'internal',
        `Enrichment failed: ${error.message}`
      );
    }
  }
);

async function enrichSingleField(
  field: FieldLocation,
  dateRange?: DateRange
): Promise<any> {
  const { fieldId, lat, lng, bbox } = field;

  const point = ee.Geometry.Point([lng, lat]);

  const region = bbox
    ? ee.Geometry.Rectangle(bbox)
    : point.buffer(100);

  const start = dateRange?.start || getDefaultStartDate();
  const end = dateRange?.end || getDefaultEndDate();

  const dwCollection = ee.ImageCollection('GOOGLE/DYNAMICWORLD/V1')
    .filterBounds(region)
    .filterDate(start, end);

  const dwComposite = dwCollection.mode();

  const bandNames = [
    'water',
    'trees',
    'grass',
    'flooded_vegetation',
    'crops',
    'shrub_and_scrub',
    'built',
    'bare',
    'snow_and_ice'
  ];

  const stats = await getRegionStats(dwComposite, region, bandNames);

  const probabilities = {
    water: stats.water || 0,
    trees: stats.trees || 0,
    grass: stats.grass || 0,
    floodedVegetation: stats.flooded_vegetation || 0,
    crops: stats.crops || 0,
    shrubAndScrub: stats.shrub_and_scrub || 0,
    built: stats.built || 0,
    bare: stats.bare || 0,
    snowAndIce: stats.snow_and_ice || 0
  };

  const dominantClass = getDominantClass(probabilities);
  const suitability = calculateLivestockSuitability(probabilities);

  return {
    fieldId,
    probabilities,
    dominantClass,
    livestockSuitability: suitability,
    timestamp: Date.now()
  };
}

function getRegionStats(
  image: any,
  region: any,
  bandNames: string[]
): Promise<any> {
  return new Promise((resolve, reject) => {
    const reducer = ee.Reducer.mean();

    image.select(bandNames).reduceRegion({
      reducer: reducer,
      geometry: region,
      scale: 10,
      maxPixels: 1e9
    }).evaluate((result: any, error: any) => {
      if (error) {
        reject(error);
      } else {
        resolve(result);
      }
    });
  });
}

function getDominantClass(probs: any): string {
  const classes = [
    { name: 'water', value: probs.water },
    { name: 'trees', value: probs.trees },
    { name: 'grass', value: probs.grass },
    { name: 'flooded_vegetation', value: probs.floodedVegetation },
    { name: 'crops', value: probs.crops },
    { name: 'shrub_scrub', value: probs.shrubAndScrub },
    { name: 'built', value: probs.built },
    { name: 'bare', value: probs.bare },
    { name: 'snow_ice', value: probs.snowAndIce }
  ];

  return classes.reduce((max, current) =>
    current.value > max.value ? current : max
  ).name;
}

function calculateLivestockSuitability(probs: any): number {
  const grassWeight = 0.40;
  const cropsWeight = 0.25;
  const shrubWeight = 0.15;
  const treesWeight = 0.10;
  const builtPenalty = -0.50;
  const waterPenalty = -0.30;

  const score =
    (probs.grass * grassWeight) +
    (probs.crops * cropsWeight) +
    (probs.shrubAndScrub * shrubWeight) +
    (probs.trees * treesWeight) +
    (probs.built * builtPenalty) +
    (probs.water * waterPenalty);

  return Math.max(0, Math.min(100, score * 100));
}

function getDefaultStartDate(): string {
  const date = new Date();
  date.setFullYear(date.getFullYear() - 1);
  return date.toISOString().split('T')[0];
}

function getDefaultEndDate(): string {
  return new Date().toISOString().split('T')[0];
}
```

## Dependencies

Add to `functions/package.json`:

```json
{
  "dependencies": {
    "@google/earthengine": "^0.1.384",
    "firebase-admin": "^11.0.0",
    "firebase-functions": "^4.0.0"
  }
}
```

## Earth Engine Setup

### 1. Enable Earth Engine API
```bash
gcloud services enable earthengine.googleapis.com
```

### 2. Create Service Account
```bash
gcloud iam service-accounts create earth-engine-sa \
  --display-name="Earth Engine Service Account"
```

### 3. Grant Permissions
```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:earth-engine-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/earthengine.viewer"
```

### 4. Register Service Account
Visit: https://signup.earthengine.google.com/#!/service_accounts

Register: `earth-engine-sa@PROJECT_ID.iam.gserviceaccount.com`

### 5. Deploy Function
```bash
cd functions
npm install
firebase deploy --only functions:enrichFieldsWithDynamicWorld
```

## Environment Configuration

Set in Firebase Console or `.env`:

```bash
EARTH_ENGINE_PROJECT=your-project-id
EARTH_ENGINE_SERVICE_ACCOUNT=earth-engine-sa@project.iam.gserviceaccount.com
```

## Testing

```bash
firebase functions:shell
```

```javascript
enrichFieldsWithDynamicWorld({
  fields: [
    {
      fieldId: "test_field",
      lat: 40.7128,
      lng: -74.0060
    }
  ]
})
```

## Performance Optimization

### Batch Processing
Process up to 50 fields per request:

```typescript
const BATCH_SIZE = 50;

if (fields.length > BATCH_SIZE) {
  throw new functions.https.HttpsError(
    'invalid-argument',
    `Maximum ${BATCH_SIZE} fields per request`
  );
}
```

### Caching
Add Redis for response caching:

```typescript
const cached = await redis.get(`dw:${fieldId}`);
if (cached) {
  return JSON.parse(cached);
}

const result = await enrichSingleField(field);
await redis.setex(`dw:${fieldId}`, 2592000, JSON.stringify(result));
```

### Region Scaling
Adjust scale based on area:

```typescript
const area = region.area().getInfo();
const scale = area > 1000000 ? 100 : 10;
```

## Error Handling

```typescript
try {
  const stats = await getRegionStats(dwComposite, region, bandNames);
} catch (error) {
  console.error(`Failed to process field ${fieldId}:`, error);

  return {
    fieldId,
    probabilities: getDefaultProbabilities(),
    dominantClass: 'unknown',
    livestockSuitability: 0,
    timestamp: Date.now(),
    error: error.message
  };
}
```

## Rate Limiting

```typescript
import { RateLimiter } from 'limiter';

const limiter = new RateLimiter({
  tokensPerInterval: 10,
  interval: 'second'
});

await limiter.removeTokens(1);
```

## Monitoring

Add Cloud Monitoring metrics:

```typescript
const startTime = Date.now();
const result = await enrichSingleField(field);
const duration = Date.now() - startTime;

console.log(`[METRIC] enrichment_duration_ms: ${duration}`);
```

## Security Rules

Ensure Firestore rules allow caching:

```javascript
match /dynamicWorldCache/{fieldId} {
  allow read, write: if request.auth != null;
}
```

## Cost Estimation

- Earth Engine API: Free for first 1000 requests/day
- Firebase Functions: ~$0.40 per 1M invocations
- Typical enrichment: 2-5 seconds
- Recommended: Cache results for 30 days

## Troubleshooting

### Earth Engine Not Initialized
```
Error: Earth Engine not initialized
```
**Solution**: Ensure service account is registered and has earthengine.viewer role

### Geometry Error
```
Error: Invalid geometry
```
**Solution**: Validate bbox coordinates are [minLng, minLat, maxLng, maxLat]

### Timeout
```
Error: Function execution timeout
```
**Solution**: Increase timeout in firebase.json:
```json
{
  "functions": {
    "timeoutSeconds": 540
  }
}
```
