import QtQuick
import "../services"

// Request normal window focus only after a deliberate press in a text field.
// A passive grab leaves cursor placement, selection and dragging to the field.
TapHandler {
    acceptedButtons: Qt.LeftButton
    gesturePolicy: TapHandler.DragThreshold
    onPressedChanged: if (pressed) IslandState.textEntryRequested(parent)
}
