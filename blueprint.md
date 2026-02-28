
# Location Tracker App Blueprint

## Overview

This document outlines the architecture and implementation of a Flutter-based Location Tracker application. The app allows users to record their GPS coordinates, view their location history, and customize settings related to data precision and app behavior.

## Implemented Style, Design, and Features

### Core Functionality
- **GPS Recording**: Users can manually record their current latitude and longitude with a single tap.
- **Location History**: The app displays a time-stamped list of the 10 most recent location records.
- **Map Integration**: Tapping a location record opens the location in a map application (Google Maps by default, or AMAP for Chinese locales).

### User Interface & Design
- **Theme**: A clean, modern design with both light and dark modes, utilizing the `google_fonts` package for custom typography (`Lato` for body, `Oswald` for titles).
- **Layout**: A `ListView` displays location records, each presented in a `Card` for clear separation and readability.
- **Interactivity**: Interactive elements include a `FloatingActionButton` for recording, `SwitchListTile` widgets for settings, and `IconButton`s in the `AppBar` for quick actions.

### Settings & Customization
- **GPS Precision**: Users can toggle between 5 and 6 digits of decimal precision for GPS coordinates.
- **Inactivity Timeout**: An optional feature automatically closes the app after 10 seconds of user inactivity to conserve resources.
- **Foreground Recording**: A setting to automatically record a new location whenever the app is brought to the foreground.
- **Localization**: The UI supports both English and Chinese, dynamically changing based on user preference.

## Current Plan & Steps (Completed)

This plan has been fully executed.

1.  **Project Setup & Dependency Management**:
    *   Initialize a new Flutter project.
    *   Add necessary packages to `pubspec.yaml`:
        *   `provider` for state management.
        *   `location` for accessing GPS data.
        *   `shared_preferences` for local data persistence.
        *   `intl` for date/time formatting.
        *   `google_fonts` for custom typography.
        *   `intent_plus` for launching native Android intents (AMAP).
        *   `url_launcher` for opening URLs (Google Maps).

2.  **State Management & Providers**:
    *   Create `settings_provider.dart` to manage theme, locale, GPS precision, and behavior toggles.
    *   Create `location_provider.dart` to manage the list of location records and handle fetching new locations.

3.  **UI Componentization**:
    *   Develop a reusable `location_card.dart` widget to display a single location record with its timestamp and coordinates. This widget will handle the logic for launching the appropriate map application.

4.  **Main Application Screen**:
    *   Design `home_screen.dart` to serve as the main UI.
    *   Integrate `AppBar` with `IconButton`s for toggling settings.
    *   Use `SwitchListTile` widgets for boolean settings.
    *   Display the list of location records using `ListView.builder` and the `LocationCard` widget.
    *   Implement the inactivity timer and app lifecycle observers.

5.  **Application Entry Point**:
    *   Configure `main.dart` to initialize `MultiProvider` for state management.
    *   Set up the main application theme, including light/dark modes and custom fonts.
    *   Define the app's localization settings.
