pragma Singleton
// From https://github.com/caelestia-dots/shell (GPLv3)
import Quickshell
import QtQml

Singleton {
    id: root

    function getBluetoothDeviceMaterialSymbol(systemIconName: string): string {
        const iconName = (systemIconName || "").toLowerCase();

        if (iconName.includes("earbud") || iconName.includes("earphone") || iconName.includes("in-ear"))
            return "earbuds";
        if (iconName.includes("headset") || iconName.includes("headphones"))
            return "headphones";
        if (iconName.includes("speaker") || iconName.includes("audio"))
            return "speaker";
        if (iconName.includes("gamepad") || iconName.includes("gaming") || iconName.includes("joystick") || iconName.includes("controller"))
            return "gamepad";
        if (iconName.includes("phone"))
            return "phone";
        if (iconName.includes("tablet"))
            return "tablet";
        if (iconName.includes("computer") || iconName.includes("laptop"))
            return "computer";
        if (iconName.includes("printer"))
            return "printer";
        if (iconName.includes("mouse"))
            return "mouse";
        if (iconName.includes("keyboard"))
            return "keyboard";
        return "bluetooth";
    }

    function isNight(): bool {
        const hour = new Date().getHours();
        return hour < 6 || hour >= 20;
    }

    // OpenWeather condition ids (weather[0].id), which is what Weather.qml reports. The table
    // this replaced was keyed on wttr.in codes, so 5xx rain, 6xx snow and 80x cloud were all
    // absent from it and every one of them drew a sun. "bedtime" is this tree's clear-night
    // glyph; the font carries no clear_night.
    function getWeatherIcon(code): string {
        const id = Number(code);
        const night = isNight();
        if (!(id >= 200))
            return "cloud_off";   // nothing read yet, or the last fetch failed
        if (id < 300)
            return "thunderstorm";
        if (id < 400)
            return "rainy_light";
        if (id < 600)
            return id === 511 ? "weather_hail" : "rainy";
        if (id < 700)
            return (id === 602 || id === 622) ? "snowing_heavy" : "snowing";
        if (id < 800)
            return "foggy";
        if (id === 800)
            return night ? "bedtime" : "clear_day";
        if (id <= 802)
            return night ? "partly_cloudy_night" : "partly_cloudy_day";
        return "cloud";
    }
}
