import QtQuick 2.1

// On the dimmed screen, above the room temperature and left of where the waste calendar shows its icon.
// It lies over the home screen, so it is there without a tile and on every page of tiles.
Image {
	id: weercodeDimIcon
	property var app

	visible: screenStateController.dimmedColors && app.codeColor !== "" && !app.isInNotificationMode
	source: visible ? "drawables/codeDim" + app.codeColor + ".png" : ""
	width: isNxt ? 88 : 70
	height: width
	x: isNxt ? 686 : 536
	y: isNxt ? 155 : 124
}
