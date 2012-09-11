import avmplus.getQualifiedClassName;

import com.daveoncode.logging.LogFileTarget;
import com.phidgets.PhidgetInterfaceKit;
import com.phidgets.events.PhidgetDataEvent;
import com.phidgets.events.PhidgetEvent;

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.display.StageDisplayState;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;
import flash.filesystem.File;
import flash.ui.Mouse;
import flash.utils.Dictionary;
import flash.utils.clearInterval;
import flash.utils.setInterval;

import mx.events.FlexEvent;
import mx.logging.ILogger;
import mx.logging.Log;
import mx.logging.LogEventLevel;
import mx.managers.CursorManager;

import org.osmf.events.TimeEvent;

import spark.components.RichEditableText;

private var phid:PhidgetInterfaceKit;
private var lastReadData:Number;
private var resetInterval:Number;
private var LOW_LIMIT:Number = 486;
private var HIGH_LIMIT:Number = 514;
private var INITIAL_REFERENCE_VALUE:Number = 500;
private const RESET_INTERVAL_VALUE:Number = 15000;
private const STEP_TIME:Number = 500;
private const INPUT_INDEX:Number = 6;
private const PIXEL_INCREMENT:Number = 13;
private const TEMPERATURE_STEP:Number = 15;
private var firstRun:Boolean = true;

[Bindable] private var temperatureLevel:Number = 500;
[Bindable] private var tempTable:Dictionary = new Dictionary();
[Bindable] private var videoSource:String;

[Bindable] private var maxReadVal:Number = 500;
[Bindable] private var minReadVal:Number = 500;

private var process:NativeProcess;
private var nativeProcessStartupInfo:NativeProcessStartupInfo

private var countingUp:Boolean = false;
private var countingDown:Boolean = false;

private var warmingInterval:Number;
private var coolingInterval:Number;

private var logger:ILogger;

private const WARMING_TEXT:String = "                                              Varme flyttes fra utsiden (jord, luft eller vann) av huset til innsiden av huset.                                              Du varierer trykket i ulike deler av varmepumpa.                                              I en varmepumpe veksler det derfor mellom væske og gass.                                              Fordampning krever energi og kondensering avgir energi.";
private const COOLING_TEXT:String = "                                              Varme flyttes fra innsiden av huset til utsiden av huset.                                              Du varierer trykket i ulike deler av varmepumpa.                                              I en varmepumpe veksler det derfor mellom væske og gass.                                              Fordampning krever energi og kondensering avgir energi.                                              Et kjøleskap er en varmepumpe.";

protected function initApp(event:FlexEvent):void {
	this.stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
	
	// get LogFileTarget's instance (LogFileTarget is a singleton)
	var target:LogFileTarget = LogFileTarget.getInstance();
	// The log file will be placed under applicationStorageDirectory folder
	target.file = File.desktopDirectory.resolvePath("miracleME.log");
	// optional (default to "MM/DD/YY")
	target.dateFormat = "DD/MM/YYYY"; 
	// optional  (default to 1024)
	target.sizeLimit = 1000000000000;
	// Trace all (default Flex's framework features)
	target.filters = ["*"];
	target.level = LogEventLevel.INFO;
	// Begin logging  (default Flex's framework features)
	Log.addTarget(target);
	
	logger = Log.getLogger( getQualifiedClassName(MiracleME).replace("::", ".") );
	logger.info("APPLICATION_START");
	
	setupAndLaunch();
}

public function setupAndLaunch():void
{     

	nativeProcessStartupInfo = new NativeProcessStartupInfo();
	var file:File = File.applicationDirectory.resolvePath("/usr/bin/python");
	nativeProcessStartupInfo.executable = file;
	
	var processArgs:Vector.<String> = new Vector.<String>();
	// -u enables Python to output to a stdout even if there is not actaully a terminal window
	processArgs[0] = "-u";
	processArgs[1] = File.applicationDirectory.resolvePath("phidget2.py").nativePath;
	nativeProcessStartupInfo.arguments = processArgs;
	
	process = new NativeProcess();
	
	process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputData);
	process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onErrorData);
	process.addEventListener(NativeProcessExitEvent.EXIT, onExit);
	process.addEventListener(IOErrorEvent.STANDARD_OUTPUT_IO_ERROR, onIOError);
	process.addEventListener(IOErrorEvent.STANDARD_ERROR_IO_ERROR, onIOError);
	
	process.start(nativeProcessStartupInfo);
}

private function setupTable():void
{
	tempTable[INITIAL_REFERENCE_VALUE -195] = 5;
	tempTable[INITIAL_REFERENCE_VALUE -180] = 6;
	tempTable[INITIAL_REFERENCE_VALUE -165] = 7;
	tempTable[INITIAL_REFERENCE_VALUE -150] = 8;
	tempTable[INITIAL_REFERENCE_VALUE -135] = 9;
	tempTable[INITIAL_REFERENCE_VALUE -120] = 10;
	tempTable[INITIAL_REFERENCE_VALUE -105] = 11;
	tempTable[INITIAL_REFERENCE_VALUE -90] = 12;
	tempTable[INITIAL_REFERENCE_VALUE -75] = 13;
	tempTable[INITIAL_REFERENCE_VALUE -60] = 14;
	tempTable[INITIAL_REFERENCE_VALUE -45] = 15;
	tempTable[INITIAL_REFERENCE_VALUE -30] = 16;
	tempTable[INITIAL_REFERENCE_VALUE -15] = 17;
	tempTable[INITIAL_REFERENCE_VALUE] = 18;
	tempTable[INITIAL_REFERENCE_VALUE +15] = 19;
	tempTable[INITIAL_REFERENCE_VALUE +30] = 20;
	tempTable[INITIAL_REFERENCE_VALUE +45] = 21;
	tempTable[INITIAL_REFERENCE_VALUE +60] = 22;
	tempTable[INITIAL_REFERENCE_VALUE +75] = 23;
	tempTable[INITIAL_REFERENCE_VALUE +90] = 24;
	tempTable[INITIAL_REFERENCE_VALUE +105] = 25;
	tempTable[INITIAL_REFERENCE_VALUE +120] = 26;
	tempTable[INITIAL_REFERENCE_VALUE +135] = 27;
	tempTable[INITIAL_REFERENCE_VALUE +150] = 28;
	tempTable[INITIAL_REFERENCE_VALUE +165] = 29;
	tempTable[INITIAL_REFERENCE_VALUE +180] = 30;
	tempTable[INITIAL_REFERENCE_VALUE +195] = 31;
	
	LOW_LIMIT = INITIAL_REFERENCE_VALUE - 16;
	HIGH_LIMIT = INITIAL_REFERENCE_VALUE + 16;
}

public function onOutputData(event:ProgressEvent):void
{
	try {
		lastReadData = Number(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
		if(firstRun)
		{
			INITIAL_REFERENCE_VALUE = temperatureLevel = lastReadData;
			setupTable();
			firstRun = false;
		}
		else
			sensorUpdate();
	}
	catch(e:Error) {
		if(e.errorID == 2030) {
			process.exit();
			process.start(nativeProcessStartupInfo);
		}
		return;
	}
}

public function onErrorData(event:ProgressEvent):void
{
	trace("ERROR -", process.standardError.readUTFBytes(process.standardError.bytesAvailable)); 
}

public function onExit(event:NativeProcessExitEvent):void
{
	trace("Process exited with ", event.exitCode);
}

public function onIOError(event:IOErrorEvent):void
{
	trace(event.toString());
}

private function onDetach(evt:PhidgetEvent):void{
	trace("Detached");
}

private function onDisconnect(evt:PhidgetEvent):void{
	trace("Disconnected");
}

private function onConnect(evt:PhidgetEvent):void{
	trace("Connected");
	this.stage.nativeWindow.activate();
	this.stage.nativeWindow.orderToBack();
	this.stage.nativeWindow.orderToFront();
	Mouse.hide();
}

private function sensorUpdate():void {
	
	if(lastReadData > maxReadVal) {
		maxReadVal = lastReadData;
	}
	
	if(lastReadData < minReadVal && lastReadData != 0) {
		minReadVal = lastReadData;
	}
	
	switch(this.currentState) {
		case "welcome":
			if(lastReadData > HIGH_LIMIT || lastReadData < LOW_LIMIT) {
				this.currentState = "simulation";
				updateIndicator(INITIAL_REFERENCE_VALUE);
				swfHP.Temp.tOut.tempOutText.text = tempTable[INITIAL_REFERENCE_VALUE];
				swfHP.Temp.tOut.y = 75 - (tempTable[INITIAL_REFERENCE_VALUE]-tempTable[INITIAL_REFERENCE_VALUE -195])*PIXEL_INCREMENT;
			}
			break;
		case "simulation":
				if(lastReadData > HIGH_LIMIT) {
					swfHP.mv_default.visible = false;
					swfHP.mv_red.visible = true;
					swfHP.mv_blue.visible = false;
					videoSource = "assets/vids/hpf.mp4";
				}
				else if(lastReadData < LOW_LIMIT) {
					swfHP.mv_default.visible = false;
					swfHP.mv_red.visible = false;
					swfHP.mv_blue.visible = true;
					videoSource = "assets/vids/hp.mp4";
				}
				
				processReadData(lastReadData);
				readVal.text = new String(lastReadData);
				tempVal.text = tempTable[temperatureLevel];	
			break;
	}
}

protected function resetApp():void {
	clearInterval(resetInterval);
	this.currentState = "welcome";
}

protected function processReadData(dat:Number):void {
	clearInterval(resetInterval);
	
	if(dat < LOW_LIMIT && banner.text != COOLING_TEXT) {
		txtAnim.stop();
		banner.text = COOLING_TEXT;
		initTxt();
	}
	else if(dat > HIGH_LIMIT && banner.text != WARMING_TEXT) {
		txtAnim.stop();
		banner.text = WARMING_TEXT;
		initTxt();
	}
	
	if(temperatureLevel == INITIAL_REFERENCE_VALUE && tempVal.text == tempTable[INITIAL_REFERENCE_VALUE] && (dat > LOW_LIMIT && dat < HIGH_LIMIT)) {
		trace("standby mode");
		clearInterval(warmingInterval);
		clearInterval(coolingInterval);
		countingUp = false;
		countingDown = false;
		videoSource = "";
		resetInterval = setInterval(resetApp, RESET_INTERVAL_VALUE);
	}
	else {
		txtAnim.resume();
		
		if(dat > temperatureLevel && !countingUp) {
			trace("up temperature detected");
			clearInterval(coolingInterval);
			countingUp = true;
			countingDown = false;
			warmingInterval = setInterval(increaseTemp, STEP_TIME);
		}
		if(dat < temperatureLevel && !countingDown) {
			trace("down temperature detected");
			clearInterval(warmingInterval);
			countingUp = false;
			countingDown = true;
			coolingInterval = setInterval(decreaseTemp, STEP_TIME);
		}
	}
	
	if(dat > LOW_LIMIT && dat < HIGH_LIMIT) {
		txtAnim.pause();
		swfHP.mv_default.visible = true;
		swfHP.mv_red.visible = false;
		swfHP.mv_blue.visible = false;
	}
}

protected function increaseTemp():void {
	clearInterval(warmingInterval);
	temperatureLevel = temperatureLevel + TEMPERATURE_STEP;
	trace("temperature increase: "+temperatureLevel);
	countingUp = false;
	tempVal.text = tempTable[temperatureLevel];
	updateIndicator(temperatureLevel);
	processReadData(lastReadData);
}

protected function updateIndicator(temp:Number):void {
	swfHP.Temp.tHus.tempHusText.text = tempTable[temp];
	swfHP.Temp.tHus.y = 75 - (tempTable[temp]-tempTable[INITIAL_REFERENCE_VALUE -195])*PIXEL_INCREMENT;
	
}

protected function decreaseTemp():void {
	clearInterval(coolingInterval);
	temperatureLevel = temperatureLevel - TEMPERATURE_STEP;
	trace("temperature decrease: "+temperatureLevel);
	countingDown = false;
	tempVal.text = tempTable[temperatureLevel];
	updateIndicator(temperatureLevel);
	processReadData(lastReadData);
}

protected function videoPlayer_durationChangeHandler(event:TimeEvent):void {
	fadeIn.play();
}

protected function placeCorrectPicture():void {
	if(videoSource == "assets/vids/hpf.mp4") {
		bckImage.source = "assets/pics/cold.png";
	}
	else {
		bckImage.source = "assets/pics/hot.png";
	}				
}

protected function initTxt():void {
	spath.valueFrom = 0;
	spath.valueTo = (banner.textDisplay as RichEditableText).contentWidth - (banner.textDisplay as RichEditableText).width;
	txtAnim.play([banner.textDisplay]);
}