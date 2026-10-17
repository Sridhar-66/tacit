import QtQuick

// The fade behind the viewer's top line. A straight alpha ramp shows a band where it ends; this one
// follows a scrim curve instead (most of the fall early, a long soft tail), so it has no edge. `hold`
// keeps full strength for that share of the height first (a PDF's line must hide the pages under it).
Rectangle {
    id: sc
    property color tint: "#1D1A19"
    property real strength: 0.6
    property real hold: 0
    function at(p) { return sc.hold + (1 - sc.hold) * p; }
    function a(k) { return Qt.rgba(sc.tint.r, sc.tint.g, sc.tint.b, sc.strength * k); }
    color: "transparent"
    gradient: Gradient {
        GradientStop { position: 0; color: sc.a(1) }
        GradientStop { position: sc.at(0); color: sc.a(1) }
        GradientStop { position: sc.at(0.19); color: sc.a(0.738) }
        GradientStop { position: sc.at(0.34); color: sc.a(0.541) }
        GradientStop { position: sc.at(0.47); color: sc.a(0.382) }
        GradientStop { position: sc.at(0.565); color: sc.a(0.278) }
        GradientStop { position: sc.at(0.65); color: sc.a(0.194) }
        GradientStop { position: sc.at(0.73); color: sc.a(0.126) }
        GradientStop { position: sc.at(0.802); color: sc.a(0.075) }
        GradientStop { position: sc.at(0.861); color: sc.a(0.042) }
        GradientStop { position: sc.at(0.91); color: sc.a(0.021) }
        GradientStop { position: sc.at(0.952); color: sc.a(0.008) }
        GradientStop { position: sc.at(0.982); color: sc.a(0.002) }
        GradientStop { position: 1; color: sc.a(0) }
    }
}
