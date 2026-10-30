import QtQuick 2.1
import FileIO 1.0

// The notification on the animation screen: visible over everything, also when the screen is dimmed
Item {
	id: weercodeAnimation
	property string eventTitle : ""
	property string eventText : ""
	property string eventColor : ""

	FileIO {
		id: eventFile
		source: "file:///qmf/qml/apps/weercode/event.json"
	}

	Timer { //allow some time for the app to close the file
		running: true
		repeat: false
		interval: 300
		onTriggered: {
			var event = JSON.parse(eventFile.read())
			eventTitle = event['title']
			eventText = event['text']
			eventColor = event['color']
		}
	}

	width: isNxt? 500:400
	height: isNxt? 200:160
	x : (parent.width - weercodeAnimation.width)/2
	y : (parent.height- weercodeAnimation.height)/2

	Rectangle {
		anchors.fill: parent
		radius: 4
		color: eventColor === "red" ? "#d7191c" : (eventColor === "orange" ? "#ff8c00" : "#ffd400")

		Column {
			anchors.centerIn: parent
			width: parent.width - (isNxt ? 64 : 48)
			spacing: isNxt ? 16 : 12

			Text {
				width: parent.width
				horizontalAlignment: Text.AlignHCenter
				wrapMode: Text.WordWrap
				text: eventTitle
				font.pixelSize: isNxt ? 32:24
				font.family: qfont.regular.name
				font.bold: true
				color: eventColor === "red" ? "white" : "black"
			}
			Text {
				width: parent.width
				horizontalAlignment: Text.AlignHCenter
				wrapMode: Text.WordWrap
				text: eventText
				font.pixelSize: isNxt ? 24:18
				font.family: qfont.regular.name
				color: eventColor === "red" ? "white" : "black"
			}
		}

		MouseArea {
			anchors.fill: parent
			onClicked: {animationscreen.animationRunning = false; weercodeAnimation.destroy();}
		}
	}

	Timer {
		interval: 500   //close soon after the app ends the notification
		running: true
		repeat: true
		onTriggered: {
			if (animationscreen.animationRunning == false) weercodeAnimation.destroy();
		}
	}
}
