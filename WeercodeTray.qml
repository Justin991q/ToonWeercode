import QtQuick 2.1
import qb.components 1.0
import qb.base 1.0

// Only while a code applies now
SystrayIcon {
	id: weercodeSystrayIcon
	property string objectName: "weercodeTray"

	visible: app.enableSystray && app.codeColor !== ""
	posIndex: 8600

	onClicked: {
		stage.openFullscreen(app.weercodeScreenUrl);
	}

	Rectangle {
		anchors.centerIn: parent
		width: isNxt ? 22 : 18
		height: width
		radius: width / 2
		color: app.plateColor(app.codeColor)
		border.width: 1
		border.color: "black"
	}
}
