import QtQuick 2.1
import qb.base 1.0
import qb.components 1.0

Tile {
	id: weercodeTile
	property bool dimState: screenStateController.dimmedColors
	// the code of now; without one what is coming is in the lines below
	property string shownColor: app.codeColor
	// dimmed and a code now: only a big icon, readable from a distance
	property bool showDimIcon: dimState && shownColor !== ""

	onClicked: {
		stage.openFullscreen(app.weercodeScreenUrl)
	}

	Image {
		id: dimIcon
		visible: showDimIcon
		source: visible ? "drawables/codeDim" + shownColor + ".png" : ""
		width: isNxt ? 126 : 100
		height: width
		anchors {
			top: parent.top
			topMargin: isNxt ? 10 : 8
			horizontalCenter: parent.horizontalCenter
		}
	}

	Text {
		visible: showDimIcon
		text: "Code " + app.colorName(shownColor)
		font.pixelSize: isNxt ? 22 : 18
		font.family: qfont.bold.name
		color: "white"
		anchors {
			top: dimIcon.bottom
			topMargin: isNxt ? 4 : 3
			horizontalCenter: parent.horizontalCenter
		}
	}

	Text {
		id: titleText
		visible: !showDimIcon
		text: app.placeName ? "Weercode " + app.placeName : "Weercode"
		width: parent.width - 2 * anchors.leftMargin
		elide: Text.ElideRight
		font.pixelSize: isNxt? 16:12
		font.family: qfont.bold.name
		anchors {
			top: parent.top
			left: parent.left
			leftMargin: isNxt? 12:9
			topMargin: isNxt? 6:5
		}
		color: dimState? dimmableColors.clockTileColor : colors.clockTileColor
	}

	Rectangle {
		id: plate
		visible: !showDimIcon
		height: isNxt? 54:42
		radius: 4
		anchors {
			top: titleText.bottom
			topMargin: isNxt? 8:6
			left: parent.left
			right: parent.right
			leftMargin: isNxt? 12:9
			rightMargin: isNxt? 12:9
		}
		color: !app.dataKnown ? "transparent" : (dimState ? "transparent" : app.plateColor(shownColor))
		border.width: (dimState || !app.dataKnown) ? 2 : 0
		border.color: !app.dataKnown ? "grey" : (dimState ? (shownColor ? app.plateColor(shownColor) : "white") : "transparent")

		Text {
			anchors.centerIn: parent
			width: parent.width - 8
			horizontalAlignment: Text.AlignHCenter
			elide: Text.ElideRight
			text: !app.dataKnown ? "Onbekend" : (shownColor ? "Code " + app.colorName(shownColor) : "Geen waarschuwing")
			font.pixelSize: (app.dataKnown && !shownColor) ? (isNxt? 20:16) : (isNxt? 28:22)
			font.family: qfont.bold.name
			color: (dimState || !app.dataKnown) ? (dimState ? "white" : "grey") : app.plateTextColor(shownColor)
		}
	}

	Column {
		visible: !showDimIcon
		anchors {
			top: plate.bottom
			topMargin: isNxt? 6:5
			left: plate.left
			right: plate.right
		}

		Text {
			width: parent.width
			horizontalAlignment: Text.AlignHCenter
			elide: Text.ElideRight
			text: !app.dataKnown ? (app.errorText || app.weerliveError || "Gegevens ophalen...")
				: (!app.codeColor && app.upcomingColor ? "Verwacht: code " + app.colorName(app.upcomingColor) : app.summaryText)
			font.pixelSize: isNxt? 16:12
			font.family: qfont.regular.name
			color: dimState? "white" : "black"
		}
		Text {
			width: parent.width
			horizontalAlignment: Text.AlignHCenter
			elide: Text.ElideRight
			text: !app.dataKnown ? "" : (!app.codeColor && app.upcomingColor ? app.summaryText + ", " + app.whenText.toLowerCase() : app.whenText)
			font.pixelSize: isNxt? 16:12
			font.family: qfont.regular.name
			color: dimState? "#bbbbbb" : "#808080"
		}
	}
}
