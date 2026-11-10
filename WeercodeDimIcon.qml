import QtQuick 2.1

// On the dimmed screen, bottom right of the thermostat's side panel, below its texts: the top of the
// panel has the burner icon and the waste calendar's icon.
// It lies over the home screen, so it is there without a tile and on every page of tiles.
Image {
	id: weercodeDimIcon
	property var app

	visible: screenStateController.dimmedColors && app.codeColor !== "" && !app.isInNotificationMode
	source: visible ? "drawables/codeDim" + app.codeColor + ".png" : ""
	width: isNxt ? 80 : 64
	height: width
	x: isNxt ? 910 : 710
	y: isNxt ? 508 : 406
}
