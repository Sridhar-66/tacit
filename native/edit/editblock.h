// Graphis's edits as one step (2026-10-15). QML's TextEdit has insert() and remove() but no edit block, so a replace
// (remove + insert), a Replace All or an indent over many lines took one Ctrl+Z per piece. apply() makes any number of
// pieces one undo step on the TextEdit's own document.
#pragma once
#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

#include <QQuickTextDocument>

class EditBlock : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Edit)
    QML_SINGLETON
public:
    using QObject::QObject;
    // edits: [[start, end, text], ...] in the document's current offsets, in any order and not overlapping; the
    // range start..end is replaced by text. Applied last first, so every offset stays the one the caller read.
    Q_INVOKABLE void apply(QQuickTextDocument *doc, const QVariantList &edits);
    // A language's comment marks from its syntax definition (KSyntaxHighlighting, the same one that colours it):
    // [line marker, block start, block end], each "" where the language has none.
    Q_INVOKABLE QStringList commentMarkers(const QString &definitionName) const;
};
