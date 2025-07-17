# HiPop Server

Backend server for the HiPop Flutter app that handles Google Places API calls securely on the server side.

## Setup

1. Install dependencies:
   ```bash
   npm install
   ```

2. Copy the environment variables:
   ```bash
   cp .env.example .env
   ```

3. Update the `.env` file with your Google Maps API Key:
   ```
   GOOGLE_MAPS_API_KEY=your_api_key_here
   PORT=3000
   ```

## Running the Server

### Development
```bash
npm run dev
```

### Production
```bash
npm start
```

## API Endpoints

### Health Check
- **GET** `/health`
- Returns server status and timestamp

### Places Autocomplete
- **GET** `/api/places/autocomplete?input={query}`
- Returns place predictions for the given query
- Minimum 3 characters required

### Place Details
- **GET** `/api/places/details?place_id={place_id}`
- Returns detailed information for a specific place

## Usage with Flutter App

The Flutter app's `PlacesService` is configured to connect to this server running on `http://localhost:3000`. Make sure the server is running before testing the Flutter app's location search functionality.

## Security Notes

- The Google Maps API key is kept secure on the server side
- CORS is enabled for development - configure appropriately for production
- Consider adding rate limiting and authentication for production use