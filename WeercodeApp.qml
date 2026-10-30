import QtQuick 2.1
import qb.components 1.0
import qb.base 1.0;
import FileIO 1.0

// The weather warnings of the KNMI (dataset KNMI-public-weather-warnings) for one place, or for the
// whole country when no place is chosen. Data: KNMI, CC BY 4.0. With a place and an own key also the
// code of Weerlive.nl: the highest code of the two counts.
App {
	id: weercodeApp
	property bool 		debugOutput : false
	property url 		tileUrl : "WeercodeTile.qml"
	property url 		thumbnailIcon: "drawables/weercodeThumb.png"
	property 			WeercodeTile weercodeTile

	property			WeercodeScreen  weercodeScreen
	property url 		weercodeScreenUrl : "WeercodeScreen.qml"
	property			WeercodeConfigScreen  weercodeConfigScreen
	property url 		weercodeConfigScreenUrl : "WeercodeConfigScreen.qml"
	property url 		trayUrl : "WeercodeTray.qml"
	property 			SystrayIcon weercodeTray
	property url 		dimIconUrl : "WeercodeDimIcon.qml"

	property string 	appVersion : ""
	property string 	filesUrl : "https://api.dataplatform.knmi.nl/open-data/v1/datasets/KNMI-public-weather-warnings/versions/1.0/files"
	// the KNMI's public key for the Open Data API, shared by everybody and valid until 1 August 2027.
	// An own (free) Open Data API key is entered on the settings screen and then used instead
	property string 	anonymousKey : "eyJvcmciOiI1ZTU1NGUxOTI3NGE5NjAwMDEyYTNlYjEiLCJpZCI6IjUzYTg1ZDBhMmQ5YzRkYzJiYWNlNzQ4NTQ2Zjk4ODExIiwiaCI6Im11cm11cjEyOCJ9"
	property string 	apiKey : ""
	property string 	weerliveUrl : "https://weerlive.nl/api/weerlive_api_v2.php"
	property string 	weerliveKey : ""
	property int		weerliveInterval : 600000  // every 10 minutes: 144 of the 300 requests a day it allows
	property int		nextWeerlive : 5000      // the first check after the start
	property int		weerliveCount : 0        // only the latest check may finish
	property double 	weerliveSuccess : 0      // ms
	property string 	weerliveError : ""
	property var 		weerliveData : ({})      // color, upcomingColor, onset, title, text

	property string 	placeName : ""           // "" = the whole country
	property double 	placeLat : 0
	property double 	placeLon : 0
	property bool 		enableNotifications : true
	property bool 		enableSystray : true
	property int		notificationSeconds : 15

	property int		checkInterval : 600000   // every 10 minutes; the list of files only, a file itself when it is new
	property int		filesToRead : 5          // the newest files that are read together
	property int		staleMinutes : 30        // no answer for this long: no code is shown, "geen waarschuwing" would be a guess
	property int		nextCheck : 5000         // the first check after the start
	property int		checkCount : 0           // only the latest check may finish
	property var 		fileCache : ({})         // file name -> what it says for this place: only a new file is downloaded
	property string 	cachedPlace : ""         // the place the cache is for
	property double 	cacheWritten : 0         // ms
	property int		cacheWriteMinutes : 15   // without news: how often the time of the last check is saved
	property bool 		refreshing : false       // a forced refresh is waiting for the KNMI
	property double 	lastSuccess : 0          // ms
	property string 	errorText : ""

	property var 		parts : []               // what the newest files say for this place, without the areas
	property var 		warnings : []            // for the screens: what still counts, most important first
	property var 		notified : ({})          // part|color -> until when it counts, ms: what was notified before

	property string 	codeColor : ""           // now: "yellow", "orange", "red", "" = none
	property string 	upcomingColor : ""       // the highest code that is still to come
	property string 	summaryText : ""         // the phenomena of the highest code now, or of what is coming
	property string 	whenText : ""            // until or from when that is
	property bool 		dataKnown : false        // false: the state is not known, also not "no warning"

	property bool 		isInNotificationMode: false
	property bool 		oldanimationRunning: 	false
	property bool 		oldisVisibleinDimState: true
	property int 		oldanimationInterval : 	1000
	property string 	oldqmlAnimationURL :  	""
	property string 	oldqmlAnimationText : 	""
	property string 	oldstaticImageT1 : 		""
	property string 	oldstaticImageT2 : 		""
	property string 	oldstaticImageT1dim : 	""
	property string 	oldstaticImageT2dim : 	""

	FileIO {
		id: weercodeSettingsFile
		source: "file:///mnt/data/tsc/weercode_userSettings.json"
	}

	FileIO {
		id: weercodeCacheFile
		source: "file:///mnt/data/tsc/weercode_cache.json"
	}

	FileIO {
		id: weercodeVersionFile
		source: "file:///qmf/qml/apps/weercode/version.txt"
	}

	signal weercodeUpdated()

	function init() {
		registry.registerWidget("screen", weercodeConfigScreenUrl, this, "weercodeConfigScreen")
		registry.registerWidget("screen", weercodeScreenUrl, this, "weercodeScreen")
		registry.registerWidget("systrayIcon", trayUrl, this, "weercodeTray")
		registry.registerWidget("tile", tileUrl, this, "weercodeTile", {thumbLabel: qsTr("Weercode"), thumbIcon: thumbnailIcon, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10, baseTileSolarWeight: 10, thumbIconVAlignment: "center"})
		Qt.createComponent(dimIconUrl).createObject(canvas.contentItem, {app: weercodeApp})
	}

	Component.onCompleted: {
		try {
			var settings = JSON.parse(weercodeSettingsFile.read())
			placeName = settings['placeName'] || ""
			placeLat = settings['placeLat'] || 0
			placeLon = settings['placeLon'] || 0
			enableNotifications = (settings['enableNotifications'] != "No")
			enableSystray = (settings['enableSystray'] != "No")
			apiKey = settings['apiKey'] || ""
			weerliveKey = settings['weerliveKey'] || ""
			notified = settings['notified'] || {}
		} catch(e) {
		}
		try {
			appVersion = weercodeVersionFile.read().trim()
		} catch(e) {
		}
		cachedPlace = placeKey()
		readCache()
		Qt.callLater(showState)    // the last known state, until the first check has answered
	}

	function placeKey() {
		return placeName + "|" + placeLat + "|" + placeLon
	}

	function readCache() {
		try {
			var cache = JSON.parse(weercodeCacheFile.read())
			// of another place, or read by another version: not valid
			if (cache.place !== placeKey() || cache.version !== appVersion) return
			fileCache = cache.fileCache || {}
			mergeFiles(Object.keys(fileCache).sort().reverse().slice(0, filesToRead))   // the name has the time
			lastSuccess = cache.lastSuccess || 0
			weerliveData = cache.weerliveData || {}
			weerliveSuccess = cache.weerliveSuccess || 0
		} catch(e) {
		}
	}

	function writeCache() {
		cacheWritten = new Date().getTime()
		weercodeCacheFile.write(JSON.stringify({
			"place" : placeKey(),
			"version" : appVersion,
			"lastSuccess" : lastSuccess,
			"fileCache" : fileCache,
			"weerliveData" : weerliveData,
			"weerliveSuccess" : weerliveSuccess
		}))
	}

	function writeSettings() {
		weercodeSettingsFile.write(JSON.stringify({
			"placeName" : placeName,
			"placeLat" : placeLat,
			"placeLon" : placeLon,
			"enableNotifications" : enableNotifications ? "Yes" : "No",
			"enableSystray" : enableSystray ? "Yes" : "No",
			"apiKey" : apiKey,
			"weerliveKey" : weerliveKey,
			"notified" : notified
		}))
	}

	function forceRefresh() {
		// everything from the sources again; what was notified stays: no notification twice
		if (refreshing) return
		refreshing = true
		fileCache = {}
		parts = []
		lastSuccess = 0
		errorText = ""
		weerliveData = {}
		weerliveSuccess = 0
		cacheWritten = 0
		weercodeCacheFile.write("")
		showState()
		checkKnmi()
		checkWeerlive()
	}

	function saveSettings() {
		writeSettings()
		if (placeKey() !== cachedPlace) {
			cachedPlace = placeKey()
			fileCache = {}      // the files have to be read again for the other place
			parts = []
			lastSuccess = 0
			weerliveData = {}
			weerliveSuccess = 0
		}
		checkKnmi()
		checkWeerlive()
	}

	function colorRank(color) {
		return color === "red" ? 3 : (color === "orange" ? 2 : (color === "yellow" ? 1 : 0))
	}

	function colorName(color) {
		return color === "red" ? "rood" : (color === "orange" ? "oranje" : "geel")
	}

	function plateColor(color) {
		if (color === "red") return "#d7191c"
		if (color === "orange") return "#ff8c00"
		if (color === "yellow") return "#ffd400"
		return "#4caf50"
	}

	function plateTextColor(color) {
		return color === "red" ? "white" : "black"
	}

	function phenomenonName(phenomenon) {
		var names = {
			"road-ice": "Gladheid", "snow": "Sneeuw", "rain": "Regen", "fog": "Mist", "thunderstorm": "Onweer",
			"wind": "Wind", "high-temperature": "Hitte", "low-temperature": "Kou", "waterspouts": "Waterhozen"
		}
		return names[phenomenon] || phenomenon
	}

	function timeText(ms) {
		var d = new Date(ms)
		var now = new Date()
		var tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1)
		var day
		if (d.toDateString() === now.toDateString()) day = "vandaag"
		else if (d.toDateString() === tomorrow.toDateString()) day = "morgen"
		else day = ["zo", "ma", "di", "wo", "do", "vr", "za"][d.getDay()]
		return day + " " + ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2)
	}

	function getUrl(url, withKey, onDone) {
		var http = new XMLHttpRequest()
		http.open("GET", url, true)
		// not on the temporary download address: it has its own signature and refuses a second one
		if (withKey) http.setRequestHeader("Authorization", apiKey ? apiKey : anonymousKey)
		http.onreadystatechange = function() {
			if (http.readyState !== 4) return
			if (debugOutput) console.log("*********Weercode: " + http.status + " " + url)
			onDone(http.status, http.status === 200 ? http.responseText : "")
		}
		http.send()
	}

	function checkKnmi() {
		checkCount++
		var check = checkCount
		getUrl(filesUrl + "?maxKeys=30&orderBy=created&sorting=desc", true, function(status, text) {
			if (check !== checkCount) return
			if (status !== 200) { checkFailed(status); return }
			try {
				// next to the JSON file of every update the list has its CAP files
				var files = JSON.parse(text).files
				var newest = []
				for (var i = 0; i < files.length && newest.length < filesToRead; i++) {
					if (/^public_warnings_.*\.json$/.test(files[i].filename)) newest.push(files[i].filename)
				}
			} catch(e) {
				checkFailed(0)
				return
			}
			if (newest.length === 0) { checkFailed(0); return }
			getFiles(newest, check)
		})
	}

	function getFiles(filenames, check) {
		// one by one and the newest first: when the KNMI stops answering what was read counts, and the
		// next check only asks for the rest
		mergeFiles(filenames)
		if (fileCache[filenames[0]]) lastSuccess = new Date().getTime()
		for (var i = 0; i < filenames.length; i++) {
			if (!fileCache[filenames[i]]) {
				getFile(filenames[i], filenames, check)
				return
			}
		}
		checkDone()
	}

	function mergeFiles(filenames) {
		// every file has the whole state of its moment: of a part only its newest version counts
		var cache = {}, seen = {}, merged = []
		for (var f = 0; f < filenames.length; f++) {
			var file = fileCache[filenames[f]]
			if (!file) continue
			cache[filenames[f]] = file
			for (var p = 0; p < file.parts.length; p++) {
				if (!seen[file.parts[p].id]) merged.push(file.parts[p])
			}
			for (var i = 0; i < file.ids.length; i++) seen[file.ids[i]] = true
		}
		fileCache = cache
		parts = merged
	}

	function getFile(filename, filenames, check) {
		getUrl(filesUrl + "/" + filename + "/url", true, function(status, text) {
			if (check !== checkCount) return
			if (status !== 200) { checkFailed(status); return }
			var address
			try {
				address = JSON.parse(text).temporaryDownloadUrl
                console.log("Weercode: downloading KNMI file: " + address)
			} catch(e) {
				checkFailed(0)
				return
			}
			getUrl(address, false, function(status, text) {
				if (check !== checkCount) return
				if (status !== 200) { checkFailed(status); return }
				try {
					fileCache[filename] = readWarnings(JSON.parse(text))
				} catch(e) {
					console.log("Weercode: the KNMI file could not be read: " + e)
					checkFailed(0)
					return
				}
				getFiles(filenames, check)
				writeCache()
			})
		})
	}

	function checkDone() {
		refreshing = false
		lastSuccess = new Date().getTime()
		errorText = ""
		nextCheck = checkInterval
		// not at every check: this is flash memory
		if (lastSuccess - cacheWritten > cacheWriteMinutes * 60000) writeCache()
		showState()
	}

	function checkFailed(status) {
		refreshing = false
		if (status === 401 || status === 403) errorText = "KNMI weigert de sleutel"
		else if (status === 429) errorText = "KNMI is even te druk"
		else if (status === 0) errorText = "Geen verbinding met het KNMI"
		else errorText = "KNMI geeft foutcode " + status
		// soon again, not all at the same moment: the public key is shared
		nextCheck = 60000 + Math.floor(Math.random() * 60000)
		showState()
	}

	function readWarnings(data) {
		var found = []
		var ids = []        // all parts, also those that do not count: an older file may not bring them back
		for (var w = 0; w < data.warnings.length; w++) {
			var warning = data.warnings[w]
			for (var a = 0; a < warning.parts.length; a++) ids.push(warning.parts[a].part_uuid)
			// the KNMI's test messages are fictional
			var operational = warning.operational_status
			if (operational === "Test" || operational === "Exercise" || operational === "Draft") continue
			if (warning.status !== "active") continue
			var texts = warning.texts && warning.texts.nl ? warning.texts.nl : {}
			for (var p = 0; p < warning.parts.length; p++) {
				var part = warning.parts[p]
				if (part.status !== "active") continue
				if (placeName && !inArea(placeLon, placeLat, part.area)) continue
				found.push({
					id: part.part_uuid,
					key: part.part_uuid + "|" + part.color,
					isWarning: warning.warning_type === "warning",
					color: part.color,
					phenomenon: phenomenonName(warning.phenomenon),
					headline: texts.headline || "",
					area: part.area_description && part.area_description.nl ? part.area_description.nl : "",
					onset: new Date(part.onset).getTime(),
					expires: new Date(part.expires).getTime()
				})
			}
		}
		return {parts: found, ids: ids}
	}

	function inArea(lon, lat, area) {
		if (area.type === "Polygon") return inPolygon(lon, lat, area.coordinates)
		if (area.type === "MultiPolygon") {
			for (var i = 0; i < area.coordinates.length; i++) {
				if (inPolygon(lon, lat, area.coordinates[i])) return true
			}
		}
		return false
	}

	function inPolygon(lon, lat, rings) {
		// a line from the point to the east crosses the rings an odd number of times when it is inside;
		// holes are rings too
		var inside = false
		for (var r = 0; r < rings.length; r++) {
			var ring = rings[r]
			for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
				if ((ring[i][1] > lat) !== (ring[j][1] > lat) &&
						lon < (ring[j][0] - ring[i][0]) * (lat - ring[i][1]) / (ring[j][1] - ring[i][1]) + ring[i][0]) {
					inside = !inside
				}
			}
		}
		return inside
	}

	function checkWeerlive() {
		nextWeerlive = weerliveInterval     // also after a failure: every request counts for the day
		weerliveCount++
		var check = weerliveCount
		weerliveError = ""
		if (!weerliveKey || !placeName) {          // it has no answer for the whole country
			weerliveData = {}
			weerliveSuccess = 0
			return
		}
		getUrl(weerliveUrl + "?key=" + encodeURIComponent(weerliveKey) + "&locatie=" + placeLat.toFixed(4) + "," + placeLon.toFixed(4), false, function(status, text) {
			if (check !== weerliveCount) return
			if (status !== 200) {
				weerliveError = status === 0 ? "Geen verbinding met Weerlive" : "Weerlive geeft foutcode " + status
				showState()
				return
			}
			try {
				var live = JSON.parse(text).liveweer[0]
				if (live.fout) {
					console.log("Weercode: Weerlive says: " + live.fout)
					weerliveError = "Weerlive weigert de key of plaats"
				} else {
					var data = readWeerlive(live)
					var changed = JSON.stringify(data) !== JSON.stringify(weerliveData)
					weerliveData = data
					weerliveSuccess = new Date().getTime()
					if (changed) writeCache()
				}
			} catch(e) {
				console.log("Weercode: the Weerlive answer could not be read: " + e)
				weerliveError = "Geen geldig antwoord van Weerlive"
			}
			showState()
		})
	}

	function readWeerlive(live) {
		var data = {color: weerliveColor(live.wrschklr), upcomingColor: "", onset: 0, title: live.lkop || "", text: live.ltekst || ""}
		// wrsch_gts moves when the KNMI issues the warning again: it is only a start when it is still to come
		var onset = (live.wrsch_gts || 0) * 1000
		if (onset > new Date().getTime()) {
			data.upcomingColor = weerliveColor(live.wrsch_gc)
			data.onset = onset
		}
		return data
	}

	function weerliveColor(name) {
		return name === "rood" ? "red" : (name === "oranje" ? "orange" : (name === "geel" ? "yellow" : ""))
	}

	function weerlivePart(color, onset, now) {
		// it has no end time: open, and until when a notification counts as seen
		return {id: "weerlive", key: "weerlive|" + color, isWarning: true, open: true, color: color, phenomenon: weerliveData.title,
				headline: weerliveData.text, area: "Bron: Weerlive", onset: onset, expires: now + 24 * 3600000}
	}

	function highestRank(list) {
		var highest = 0
		for (var i = 0; i < list.length; i++) highest = Math.max(highest, colorRank(list[i].color))
		return highest
	}

	function currentText(part) {
		return part.open ? "Nu" : "Nu, tot " + timeText(part.expires)
	}

	function upcomingText(part) {
		return "Vanaf " + timeText(part.onset) + (part.open ? "" : " tot " + timeText(part.expires))
	}

	function byImportance(a, b) {
		return (colorRank(b.color) - colorRank(a.color)) || (a.onset - b.onset)
	}

	function joinPhenomena(list, color) {
		var names = []
		for (var i = 0; i < list.length; i++) {
			if (list[i].color === color && names.indexOf(list[i].phenomenon) < 0) names.push(list[i].phenomenon)
		}
		return names.join(", ")
	}

	function showState() {
		// also without a new file: a warning starts and ends by the clock
		var now = new Date().getTime()
		var current = [], upcoming = [], possible = []
		for (var i = 0; i < parts.length; i++) {
			var part = parts[i]
			if (part.expires <= now) continue
			if (!part.isWarning) possible.push(part)
			else if (part.onset <= now) current.push(part)
			else upcoming.push(part)
		}
		// Weerlive only counts when it says more than the KNMI: the same warning is not shown twice
		var weerliveKnown = weerliveSuccess > 0 && now - weerliveSuccess < staleMinutes * 60000
		if (weerliveKnown) {
			if (colorRank(weerliveData.color) > highestRank(current)) current.push(weerlivePart(weerliveData.color, now, now))
			if (colorRank(weerliveData.upcomingColor) > highestRank(upcoming)) upcoming.push(weerlivePart(weerliveData.upcomingColor, weerliveData.onset, now))
		}
		current.sort(byImportance)
		upcoming.sort(byImportance)
		possible.sort(byImportance)

		var list = []
		for (i = 0; i < current.length; i++) list.push(screenItem(current[i], "Code " + colorName(current[i].color), currentText(current[i])))
		for (i = 0; i < upcoming.length; i++) list.push(screenItem(upcoming[i], "Code " + colorName(upcoming[i].color), upcomingText(upcoming[i])))
		for (i = 0; i < possible.length; i++) list.push(screenItem(possible[i], "Mogelijk gevaarlijk weer", "Vanaf " + timeText(possible[i].onset) + " tot " + timeText(possible[i].expires)))
		warnings = list

		dataKnown = weerliveKnown || (lastSuccess > 0 && now - lastSuccess < staleMinutes * 60000)
		codeColor = (dataKnown && current.length > 0) ? current[0].color : ""
		upcomingColor = (dataKnown && upcoming.length > 0) ? upcoming[0].color : ""
		if (codeColor) {
			summaryText = joinPhenomena(current, codeColor)
			whenText = current[0].open ? "Nu" : "Tot " + timeText(current[0].expires)
		} else if (upcomingColor) {
			summaryText = joinPhenomena(upcoming, upcomingColor)
			whenText = "Vanaf " + timeText(upcoming[0].onset)
		} else {
			summaryText = ""
			whenText = ""
		}
		if (dataKnown) notifyNew(current.concat(upcoming))
		weercodeUpdated()
	}

	function screenItem(part, title, when) {
		return {title: title, when: when, phenomenon: part.phenomenon, color: part.isWarning ? part.color : "",
				headline: part.headline, area: part.area}
	}

	function notifyNew(list) {
		if (isInNotificationMode) return     // the next check again
		var now = new Date().getTime()
		var seen = notified
		var changed = false
		var fresh = []
		for (var key in seen) {
			if (seen[key] <= now) { delete seen[key]; changed = true }
		}
		for (var i = 0; i < list.length; i++) {
			if (!seen[list[i].key]) {
				seen[list[i].key] = list[i].expires
				fresh.push(list[i])
				changed = true
			}
		}
		if (changed) {
			notified = seen
			writeSettings()
		}
		if (fresh.length === 0 || !enableNotifications) return
		fresh.sort(byImportance)
		var first = fresh[0]
		var when = first.onset > now ? "Vanaf " + timeText(first.onset) : (first.open ? "Nu" : "Tot " + timeText(first.expires))
		var more = fresh.length > 1 ? " (+" + (fresh.length - 1) + " meer)" : ""
		createScreenNotification("Code " + colorName(first.color) + ": " + first.phenomenon, when + more, first.color)
	}

	function testScreenNotification() {
		if (isInNotificationMode) return
		createScreenNotification("Code geel: testmelding", "Zo ziet een nieuwe waarschuwing eruit", "yellow")
	}

	Timer {
		id: checkTimer
		interval: nextCheck
		repeat: true
		running: true
		onTriggered: checkKnmi()
	}

	Timer {
		id: weerliveTimer
		interval: nextWeerlive
		repeat: true
		running: true
		onTriggered: checkWeerlive()
	}

	function createScreenNotification(title, text, color) {
		isInNotificationMode = true
		oldanimationRunning = animationscreen.animationRunning
		oldisVisibleinDimState = animationscreen.isVisibleinDimState
		oldanimationInterval = animationscreen.animationInterval
		oldqmlAnimationURL = animationscreen.qmlAnimationURL
		oldqmlAnimationText = animationscreen.qmlAnimationText
		oldstaticImageT1 = animationscreen.staticImageT1
		oldstaticImageT2 = animationscreen.staticImageT2
		oldstaticImageT1dim = animationscreen.staticImageT1dim
		oldstaticImageT2dim = animationscreen.staticImageT2dim

		animationscreen.animationRunning = false

		var doc = new XMLHttpRequest()
		doc.open("PUT", "file:///qmf/qml/apps/weercode/event.json")
		doc.send(JSON.stringify({"title": title, "text": text, "color": color}))
		smallDelayTimer.running = true
	}

	Timer {
		id: smallDelayTimer   //delay to show the notification
		interval: 100
		repeat: false
		running: false
		onTriggered: {
			animationscreen.qmlAnimationURL = "file:///qmf/qml/apps/weercode/WeercodeAnimation.qml"
			animationscreen.animationInterval = 100000
			animationscreen.isVisibleinDimState = true
			if (!oldanimationRunning) {
				animationscreen.staticImageT1 = ""
				animationscreen.staticImageT2 = ""
				animationscreen.staticImageT1dim = ""
				animationscreen.staticImageT2dim = ""
			}
			animationscreen.animationRunning = true
			notificationTimer.running = true
		}
	}

	Timer {
		id: notificationTimer   //delay to hide the notification
		interval: notificationSeconds * 1000
		repeat: false
		running: false
		onTriggered: {
			animationscreen.animationRunning = false
			animationscreen.qmlAnimationURL = ""
			smallDelayTimer2.running = true
		}
	}

	Timer {
		id: smallDelayTimer2  //delay to return to the old animation
		interval: 3000
		repeat: false
		running: false
		onTriggered: {
			if (oldanimationRunning) {
				animationscreen.isVisibleinDimState = oldisVisibleinDimState
				animationscreen.animationInterval = oldanimationInterval
				animationscreen.qmlAnimationURL = oldqmlAnimationURL
				animationscreen.qmlAnimationText = oldqmlAnimationText
				animationscreen.staticImageT1 = oldstaticImageT1
				animationscreen.staticImageT2 = oldstaticImageT2
				animationscreen.staticImageT1dim = oldstaticImageT1dim
				animationscreen.staticImageT2dim = oldstaticImageT2dim
				animationscreen.animationRunning = true
			} else {
				animationscreen.animationRunning = false
				animationscreen.isVisibleinDimState = false
			}
			isInNotificationMode = false
		}
	}
}
