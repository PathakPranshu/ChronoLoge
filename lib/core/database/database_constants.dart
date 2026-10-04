abstract final class DatabaseConstants {
  static const name = 'chronologe.db';
  static const version = 7;
}

abstract final class DiaryEntriesTable {
  static const name = 'diary_entries';
  static const date = 'date';
  static const title = 'title';
  static const textData = 'text_data';
  static const mood = 'mood';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
}

abstract final class DiaryMediaTable {
  static const name = 'diary_media';
  static const id = 'id';
  static const entryDate = 'entry_date';
  static const mediaLocation = 'media_location';
  static const mediaType = 'media_type';
  static const sortOrder = 'sort_order';

  static const imageType = 'image';
  static const voiceMemoType = 'voice_memo';
}

abstract final class DiaryTimelineItemsTable {
  static const name = 'diary_timeline_items';
  static const id = 'id';
  static const entryDate = 'entry_date';
  static const occurredAt = 'occurred_at';
  static const textData = 'text_data';
  static const mood = 'mood';
  static const imageLocations = 'image_locations';
  static const voiceMemoLocations = 'voice_memo_locations';
  static const source = 'source';
  static const locationLabel = 'location_label';
  static const weatherLabel = 'weather_label';
  static const eventType = 'event_type';
  static const placeId = 'place_id';
  static const visitId = 'visit_id';
  static const tripId = 'trip_id';
  static const weatherSnapshotId = 'weather_snapshot_id';
  static const confidence = 'confidence';
}

abstract final class LocationSamplesTable {
  static const name = 'location_samples';
  static const id = 'id';
  static const recordedAt = 'recorded_at';
  static const latitude = 'latitude';
  static const longitude = 'longitude';
  static const accuracyMetres = 'accuracy_metres';
  static const speedMetresSecond = 'speed_metres_second';
  static const activity = 'activity';
  static const activityConfidence = 'activity_confidence';
}

abstract final class PlacesTable {
  static const name = 'places';
  static const id = 'id';
  static const nameColumn = 'name';
  static const latitude = 'latitude';
  static const longitude = 'longitude';
  static const radiusMetres = 'radius_metres';
  static const category = 'category';
  static const isUserNamed = 'is_user_named';
  static const firstVisitedAt = 'first_visited_at';
  static const lastVisitedAt = 'last_visited_at';
  static const visitCount = 'visit_count';
  static const isConfirmed = 'is_confirmed';
  static const isIgnored = 'is_ignored';
}

abstract final class VisitsTable {
  static const name = 'visits';
  static const id = 'id';
  static const placeId = 'place_id';
  static const arrivedAt = 'arrived_at';
  static const departedAt = 'departed_at';
  static const latitude = 'latitude';
  static const longitude = 'longitude';
  static const confidence = 'confidence';
  static const isFirstVisit = 'is_first_visit';
}

abstract final class TripsTable {
  static const name = 'trips';
  static const id = 'id';
  static const startedAt = 'started_at';
  static const endedAt = 'ended_at';
  static const startVisitId = 'start_visit_id';
  static const endVisitId = 'end_visit_id';
  static const transportMode = 'transport_mode';
  static const distanceMetres = 'distance_metres';
  static const confidence = 'confidence';
}

abstract final class WeatherSnapshotsTable {
  static const name = 'weather_snapshots';
  static const id = 'id';
  static const observedAt = 'observed_at';
  static const retrievedAt = 'retrieved_at';
  static const latitude = 'latitude';
  static const longitude = 'longitude';
  static const temperatureCelsius = 'temperature_celsius';
  static const apparentTemperatureCelsius = 'apparent_temperature_celsius';
  static const precipitationMm = 'precipitation_mm';
  static const cloudCoverPercent = 'cloud_cover_percent';
  static const windSpeedKph = 'wind_speed_kph';
  static const weatherCode = 'weather_code';
  static const provider = 'provider';
  static const isHistorical = 'is_historical';
}

abstract final class MemoryPromptsTable {
  static const name = 'memory_prompts';
  static const id = 'id';
  static const visitId = 'visit_id';
  static const timelineItemId = 'timeline_item_id';
  static const promptType = 'prompt_type';
  static const createdAt = 'created_at';
  static const shownAt = 'shown_at';
  static const respondedAt = 'responded_at';
  static const status = 'status';
}

abstract final class SettingsTable {
  static const name = 'settings';
  static const setting = 'setting';
  static const value = 'value';
}
