// The notch's sand (2026-10-15): grains in a thin glass tank that the voice lifts, run on the GPU every frame.
// The physics is position-based dynamics (live/pbd_shaders.py, measured in sandpbd.py against the approved film);
// the voice comes in as three bands (low, mid, high) from Flow.
#pragma once
#include <QQuickRhiItem>
#include <QElapsedTimer>
#include <QtQml/qqmlregistration.h>

class SandItem : public QQuickRhiItem
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Sand)
    // the voice, 0..1.3 each, as Flow sends them (20 per second); smoothed here as the film's analysis did
    Q_PROPERTY(qreal low MEMBER m_low NOTIFY voiceChanged)
    Q_PROPERTY(qreal mid MEMBER m_mid NOTIFY voiceChanged)
    Q_PROPERTY(qreal high MEMBER m_high NOTIFY voiceChanged)
    // listening: true raises the bed from under the floor; false levels it flat, then it rests
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    // how hard the voice drives the sand (live-tunable from QML; defaults = sandpbd.py's tested values)
    Q_PROPERTY(qreal puff MEMBER m_puff NOTIFY tuneChanged)          // a vowel burst's air speed (px/s)
    Q_PROPERTY(qreal lift MEMBER m_lift NOTIFY tuneChanged)          // the low band's lift at the top, in grain weights
    Q_PROPERTY(qreal ventRate MEMBER m_ventRate NOTIFY tuneChanged)  // vowel bursts per second at full voice
    Q_PROPERTY(qreal ventWidth MEMBER m_ventWidth NOTIFY tuneChanged) // a burst's width, x the film's 18-50 px
    Q_PROPERTY(qreal hiss MEMBER m_hiss NOTIFY tuneChanged)          // a hiss puff's air speed (px/s)
    Q_PROPERTY(qreal shake MEMBER m_shake NOTIFY tuneChanged)        // the vowels' taps through the bed, in g at full voice
    // the physics' GPU time per frame (ms), for checks
    Q_PROPERTY(qreal gpuMs READ gpuMs NOTIFY gpuMsChanged)
public:
    SandItem();
    bool active() const { return m_active; }
    void setActive(bool a);
    qreal gpuMs() const { return m_gpuMs; }

    qreal m_low = 0, m_mid = 0, m_high = 0;
    qreal m_puff = 6800, m_lift = 2.5, m_ventRate = 220, m_ventWidth = 1.0, m_hiss = 1500, m_shake = 3.0;
    bool m_active = false;
    qint64 m_activeChangedAt = 0;   // ms on m_clock
    QElapsedTimer m_clock;
    qreal m_gpuMs = 0;

signals:
    void voiceChanged();
    void tuneChanged();
    void activeChanged();
    void gpuMsChanged();
    void settled();                 // after the bed levelled at the end: the notch can close

protected:
    QQuickRhiItemRenderer *createRenderer() override;
    friend class SandRenderer;
};
