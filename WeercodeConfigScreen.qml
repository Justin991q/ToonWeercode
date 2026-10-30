import QtQuick 2.1
import BasicUIControls 1.0
import qb.components 1.0

Screen {
	id: weercodeConfigScreen
	screenTitle: "Weercode instellingen"

	property string tempPlaceName : ""
	property double tempPlaceLat : 0
	property double tempPlaceLon : 0
	property bool tempNotifications : true
	property bool tempSystray : true
	property string tempApiKey : ""
	property string tempWeerliveKey : ""
	property bool firstShown : true  // closing the keyboard shows the screen again: keep what is not saved yet
	property string searchStatus : ""
	property int searchCount : 0      // only the latest search may fill the list

	onShown: {
		addCustomTopRightButton("Opslaan")
		if (firstShown) {
			tempPlaceName = app.placeName
			tempPlaceLat = app.placeLat
			tempPlaceLon = app.placeLon
			tempNotifications = app.enableNotifications
			notificationToggle.isSwitchedOn = tempNotifications
			tempSystray = app.enableSystray
			systrayToggle.isSwitchedOn = tempSystray
			tempApiKey = app.apiKey
			tempWeerliveKey = app.weerliveKey
			placeEdit.inputText = ""
			placesModel.clear()
			searchStatus = ""
			firstShown = false
		}
	}

	onCustomButtonClicked: {
		app.placeName = tempPlaceName
		app.placeLat = tempPlaceLat
		app.placeLon = tempPlaceLon
		app.enableNotifications = tempNotifications
		app.enableSystray = tempSystray
		app.apiKey = tempApiKey
		app.weerliveKey = tempWeerliveKey
		app.saveSettings()
		firstShown = true
		hide()
	}

	function saveApiKey(text) {
		tempApiKey = text.replace(/\s/g, "")
	}

	function saveWeerliveKey(text) {
		tempWeerliveKey = text.replace(/\s/g, "")
	}

	function shortKey(key) {
		// only the ends: the whole key shows when it is edited
		return key.length > 12 ? key.slice(0, 4) + "..." + key.slice(-6) : key
	}

	function searchPlaces(text) {
		placeEdit.inputText = text
		placesModel.clear()
		searchStatus = ""
		searchCount++
		var search = searchCount
		if (!text) return
		searchStatus = "Zoeken..."
		// the place register of the Dutch government, no key needed
		var http = new XMLHttpRequest()
		http.open("GET", "https://api.pdok.nl/bzk/locatieserver/search/v3_1/free?fq=type:woonplaats&rows=6&fl=woonplaatsnaam,provincienaam,centroide_ll&q=" + encodeURIComponent(text), true)
		http.onreadystatechange = function() {
			if (http.readyState !== 4 || search !== searchCount) return
			searchStatus = "Zoeken lukt nu niet"
			if (http.status !== 200) return
			var docs
			try {
				docs = JSON.parse(http.responseText).response.docs
			} catch(e) {
				return
			}
			searchStatus = docs.length === 0 ? "Geen plaats gevonden" : ""
			for (var i = 0; i < docs.length; i++) {
				var point = docs[i].centroide_ll.match(/POINT\(([-\d.]+) ([-\d.]+)\)/)
				if (point) placesModel.append({name: docs[i].woonplaatsnaam, province: docs[i].provincienaam,
											   lon: parseFloat(point[1]), lat: parseFloat(point[2])})
			}
		}
		http.send()
	}

	Text {
		id: chosenText
		text: "Waarschuwingen voor: " + (tempPlaceName ? tempPlaceName : "heel Nederland")
		font.family: qfont.semiBold.name
		font.pixelSize: isNxt ? 18:14
		anchors {
			top: parent.top
			left: parent.left
			leftMargin: 20
			topMargin: isNxt? 16:12
		}
	}

	EditTextLabel4421 {
		id: placeEdit
		width: isNxt ? 400 : 320
		height: 30
		inputText: ""
		leftTextAvailableWidth: 100
		leftText: "Plaats: "
		labelFontSize: isNxt ? 18:14
		labelFontFamily: qfont.semiBold.name
		anchors {
			left: chosenText.left
			top: chosenText.bottom
			topMargin: isNxt? 16:12
		}
		onClicked: {
			qkeyboard.open(placeEdit.leftText, placeEdit.inputText, searchPlaces)
		}
	}

	Rectangle {
		id: placesContainer
		width: placeEdit.width
		height: isNxt? 200:160
		color: "white"
		radius: isNxt ? 5 : 4
		border.color: "black"
		border.width: isNxt ? 3 : 2
		anchors {
			top: placeEdit.bottom
			topMargin: isNxt? 12:10
			left: chosenText.left
		}

		ListModel {
			id: placesModel
		}

		Column {
			anchors {
				fill: parent
				margins: isNxt ? 6 : 5
			}
			Repeater {
				model: placesModel
				Rectangle {
					width: parent.width
					height: isNxt ? 31 : 25
					color: (model.name === tempPlaceName && model.lat === tempPlaceLat) ? "lightsteelblue" : "transparent"
					radius: isNxt ? 5 : 4
					Text {
						anchors {
							left: parent.left
							leftMargin: isNxt ? 6 : 5
							verticalCenter: parent.verticalCenter
						}
						text: model.name + " (" + model.province + ")"
						font.pixelSize: isNxt ? 18:14
					}
					MouseArea {
						anchors.fill: parent
						onClicked: {
							tempPlaceName = model.name
							tempPlaceLat = model.lat
							tempPlaceLon = model.lon
						}
					}
				}
			}
		}

		Text {
			anchors.centerIn: parent
			width: parent.width - 20
			horizontalAlignment: Text.AlignHCenter
			wrapMode: Text.WordWrap
			text: searchStatus
			font.family: qfont.semiBold.name
			font.pixelSize: isNxt ? 18:14
			color: "grey"
			visible: searchStatus !== ""
		}
	}

	NewTextLabel {
		width: placesContainer.width
		height: isNxt ? 40:32
		buttonActiveColor: "lightgrey"
		buttonHoverColor: "blue"
		enabled: true
		textColor: "black"
		buttonText: "Heel Nederland"
		anchors {
			top: placesContainer.bottom
			left: chosenText.left
			topMargin: isNxt? 6:5
		}
		onClicked: {
			tempPlaceName = ""
			tempPlaceLat = 0
			tempPlaceLon = 0
		}
	}

	Text {
		id: notificationText
		text: "Melding bij nieuwe waarschuwing: "
		font.pixelSize: isNxt ? 18:14
		font.family: qfont.semiBold.name
		anchors {
			left: placeEdit.right
			leftMargin: isNxt ? 30:24
			verticalCenter: notificationToggle.verticalCenter
		}
	}

	OnOffToggle {
		id: notificationToggle
		height: 30
		anchors {
			left: notificationText.right
			top: placeEdit.top
			leftMargin: isNxt ? 18:14
		}
		leftIsSwitchedOn: false
		onSelectedChangedByUser: tempNotifications = isSwitchedOn
	}

	NewTextLabel {
		id: testButton
		width: isNxt ? 160 : 128
		height: isNxt ? 32 : 26
		buttonActiveColor: "lightgreen"
		buttonHoverColor: "blue"
		enabled: true
		textColor: "black"
		buttonText: "Test melding"
		anchors {
			left: notificationText.left
			top: notificationToggle.bottom
			topMargin: isNxt ? 10:8
		}
		onClicked: app.testScreenNotification()
	}

	Text {
		id: systrayText
		text: "Icoon in systray bij een code: "
		font.pixelSize: isNxt ? 18:14
		font.family: qfont.semiBold.name
		anchors {
			left: notificationText.left
			verticalCenter: systrayToggle.verticalCenter
		}
	}

	OnOffToggle {
		id: systrayToggle
		height: 30
		anchors {
			left: systrayText.right
			top: testButton.bottom
			topMargin: isNxt ? 10:8
			leftMargin: isNxt ? 18:14
		}
		leftIsSwitchedOn: false
		onSelectedChangedByUser: tempSystray = isSwitchedOn
	}

	Text {
		id: apiKeyText
		text: "Eigen KNMI Open Data API-key (optioneel):"
		font.pixelSize: isNxt ? 18:14
		font.family: qfont.semiBold.name
		anchors {
			left: notificationText.left
			top: systrayToggle.bottom
			topMargin: isNxt ? 20:16
		}
	}

	EditTextLabel4421 {
		id: apiKeyEdit
		height: 30
		inputText: shortKey(tempApiKey)
		leftTextAvailableWidth: 100
		leftText: "API-key: "
		labelFontSize: isNxt ? 18:14
		labelFontFamily: qfont.semiBold.name
		anchors {
			left: notificationText.left
			right: clearKeyButton.left
			rightMargin: isNxt ? 10:8
			top: apiKeyText.bottom
			topMargin: isNxt ? 10:8
		}
		onClicked: {
			qkeyboard.open("KNMI Open Data API-key", tempApiKey, saveApiKey)
		}
	}

	NewTextLabel {
		id: clearKeyButton
		width: isNxt ? 70 : 56
		height: 30
		buttonActiveColor: "lightgrey"
		buttonHoverColor: "blue"
		enabled: true
		textColor: "black"
		buttonText: "Wis"
		anchors {
			right: parent.right
			rightMargin: 20
			top: apiKeyEdit.top
		}
		onClicked: tempApiKey = ""
	}

	Text {
		id: apiKeyHint
		text: "De app heeft een key voor de Open Data API van het KNMI nodig. "
			+ (tempApiKey ? "Na opslaan gebruikt de app deze key." : "Zonder eigen key: de openbare key, die iedereen deelt en daardoor soms vol zit.")
		wrapMode: Text.WordWrap
		font.pixelSize: isNxt ? 15:12
		font.family: qfont.regular.name
		color: "grey"
		anchors {
			left: notificationText.left
			right: parent.right
			rightMargin: 20
			top: apiKeyEdit.bottom
			topMargin: isNxt ? 8:6
		}
	}

	EditTextLabel4421 {
		id: weerliveKeyEdit
		height: 30
		inputText: shortKey(tempWeerliveKey)
		leftTextAvailableWidth: 100
		leftText: "Weerlive: "
		labelFontSize: isNxt ? 18:14
		labelFontFamily: qfont.semiBold.name
		anchors {
			left: notificationText.left
			right: clearWeerliveButton.left
			rightMargin: isNxt ? 10:8
			top: apiKeyHint.bottom
			topMargin: isNxt ? 14:10
		}
		onClicked: {
			qkeyboard.open("Weerlive API-key", tempWeerliveKey, saveWeerliveKey)
		}
	}

	NewTextLabel {
		id: clearWeerliveButton
		width: isNxt ? 70 : 56
		height: 30
		buttonActiveColor: "lightgrey"
		buttonHoverColor: "blue"
		enabled: true
		textColor: "black"
		buttonText: "Wis"
		anchors {
			right: parent.right
			rightMargin: 20
			top: weerliveKeyEdit.top
		}
		onClicked: tempWeerliveKey = ""
	}

	Text {
		text: "Optioneel, met een gekozen plaats: de hoogste code van KNMI en Weerlive telt. Key aanvragen op weerlive.nl."
		wrapMode: Text.WordWrap
		font.pixelSize: isNxt ? 15:12
		font.family: qfont.regular.name
		color: "grey"
		anchors {
			left: notificationText.left
			right: parent.right
			rightMargin: 20
			top: weerliveKeyEdit.bottom
			topMargin: isNxt ? 8:6
		}
	}

	Text {
		text: (app.appVersion ? "Versie " + app.appVersion + ", " : "") + "bron: KNMI en Weerlive.nl"
		font.pixelSize: isNxt ? 15:12
		font.family: qfont.regular.name
		color: "grey"
		anchors {
			left: notificationText.left
			bottom: parent.bottom
			bottomMargin: isNxt ? 12:10
		}
	}
}
