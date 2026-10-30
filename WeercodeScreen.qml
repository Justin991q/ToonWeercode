import QtQuick 2.1
import BasicUIControls 1.0
import qb.components 1.0

Screen {
	id: weercodeScreen
	screenTitle: "Weercode"

	onShown: {
		addCustomTopRightButton("Instellingen")
		updateList()
	}

	onCustomButtonClicked: {
		stage.openFullscreen(app.weercodeConfigScreenUrl)
	}

	Component.onCompleted: {
		app.weercodeUpdated.connect(updateList)
	}

	Component.onDestruction: app.weercodeUpdated.disconnect(updateList)

	function updateList() {
		warningModel.clear()
		for (var i = 0; i < app.warnings.length; i++) {
			warningModel.append(app.warnings[i])
		}
	}

	ListModel {
		id: warningModel
	}

	Text {
		id: placeText
		text: (app.placeName ? app.placeName : "Heel Nederland") + (app.errorText ? "  -  " + app.errorText : "") + (app.weerliveError ? "  -  " + app.weerliveError : "")
		font.pixelSize: isNxt? 25:20
		font.family: qfont.bold.name
		anchors {
			top: parent.top
			topMargin: isNxt? 12:10
			left: parent.left
			leftMargin: isNxt? 20:16
		}
	}

	Text {
		id: emptyText
		anchors.centerIn: parent
		visible: warningModel.count === 0
		text: app.refreshing ? "Gegevens ophalen..." : (app.dataKnown ? "Geen waarschuwingen" : "De actuele waarschuwingen zijn niet bekend")
		font.pixelSize: isNxt? 25:20
		font.family: qfont.bold.name
		color: "grey"
	}

	ListView {
		id: warningList
		clip: true
		spacing: isNxt? 10:8
		model: warningModel
		anchors {
			top: placeText.bottom
			topMargin: isNxt? 10:8
			bottom: refreshButton.top
			bottomMargin: isNxt? 6:5
			left: parent.left
			leftMargin: isNxt? 20:16
			right: upButton.left
			rightMargin: isNxt? 12:10
		}

		delegate: Item {
			width: warningList.width
			height: Math.max(textColumn.height, isNxt? 50:40)

			Rectangle {
				id: colorBar
				width: isNxt? 14:11
				height: parent.height
				radius: 2
				color: model.color ? app.plateColor(model.color) : "#9e9e9e"
			}
			Column {
				id: textColumn
				spacing: isNxt? 2:1
				anchors {
					left: colorBar.right
					leftMargin: isNxt? 10:8
					right: parent.right
				}
				Text {
					width: parent.width
					elide: Text.ElideRight
					text: model.title + ": " + model.phenomenon
					font.pixelSize: isNxt? 20:16
					font.family: qfont.bold.name
				}
				Text {
					width: parent.width
					elide: Text.ElideRight
					text: model.when + "  -  " + model.area
					font.pixelSize: isNxt? 16:12
					font.family: qfont.regular.name
					color: "#606060"
				}
				Text {
					width: parent.width
					wrapMode: Text.WordWrap
					text: model.headline
					font.pixelSize: isNxt? 16:12
					font.family: qfont.regular.name
				}
			}
		}
	}

	IconButton {
		id: upButton
		anchors {
			top: warningList.top
			right: parent.right
			rightMargin: isNxt? 12:10
		}
		visible: warningList.contentHeight > warningList.height
		iconSource: "qrc:/tsc/up.png"
		onClicked: warningList.contentY = Math.max(0, warningList.contentY - warningList.height * 0.8)
	}

	IconButton {
		id: downButton
		anchors {
			bottom: warningList.bottom
			right: parent.right
			rightMargin: isNxt? 12:10
		}
		visible: upButton.visible
		iconSource: "qrc:/tsc/down.png"
		onClicked: warningList.contentY = Math.min(warningList.contentHeight - warningList.height, warningList.contentY + warningList.height * 0.8)
	}

	NewTextLabel {
		id: refreshButton
		width: isNxt ? 130 : 104
		height: isNxt ? 40 : 32
		buttonActiveColor: "lightgrey"
		buttonHoverColor: "blue"
		enabled: !app.refreshing
		textColor: "black"
		buttonText: app.refreshing ? "Bezig..." : "Ververs"
		anchors {
			right: parent.right
			rightMargin: isNxt? 12:10
			bottom: parent.bottom
			bottomMargin: isNxt? 6:5
		}
		onClicked: app.forceRefresh()
	}

	Text {
		id: sourceText
		text: "Bron: KNMI" + (app.weerliveKey && app.placeName ? " en Weerlive.nl" : "") + (app.lastSuccess > 0 ? ", bijgewerkt " + app.timeText(app.lastSuccess) : "")
		font.pixelSize: isNxt? 15:12
		font.family: qfont.regular.name
		color: "grey"
		anchors {
			left: parent.left
			leftMargin: isNxt? 20:16
			bottom: parent.bottom
			bottomMargin: isNxt? 10:8
		}
	}
}
