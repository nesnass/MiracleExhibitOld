import avmplus.getQualifiedClassName;

import com.daveoncode.logging.LogFileTarget;
import com.greensock.TweenLite;
import com.phidgets.PhidgetInterfaceKit;
import com.phidgets.events.PhidgetDataEvent;
import com.phidgets.events.PhidgetEvent;

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.display.StageDisplayState;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.MouseEvent;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;
import flash.events.TimerEvent;
import flash.filesystem.File;
import flash.ui.Mouse;
import flash.utils.Dictionary;
import flash.utils.Timer;
import flash.utils.clearInterval;
import flash.utils.setInterval;

import mx.events.FlexEvent;
import mx.logging.ILogger;
import mx.logging.Log;
import mx.logging.LogEventLevel;
import mx.managers.CursorManager;

private var phid:PhidgetInterfaceKit;
private var lastReadData:Number;
private var resetInterval:Number;
private var seasonalOffset:Number = 130;
private var LOW_LIMIT:uint = 480;
private var HIGH_LIMIT:uint = 520;
private var LOW_LIMIT_GAME:uint = 486;
private var HIGH_LIMIT_GAME:uint = 514;
private var INITIAL_REFERENCE_VALUE:uint = 500;
private var TEMP_TO_REFERENCE_RATIO:Number = 0.1;
private const RESET_INTERVAL_VALUE:uint = 15000;
private const STEP_TIME:uint = 250;
private const PIXEL_INCREMENT:uint = 7;
private const TEMPERATURE_STEP:uint = 15;
private const MONTH_INTERVAL:uint = 2000;
private const MONTH_COUNTS:uint = 11;
private const COUNTDOWN_INTERVAL:uint = 2000;
private const COUNTDOWN_SECONDS:uint = 3;
private const INSTRUCTION_INTERVAL:uint = 3000;
private var gameStateReady:Boolean = false;
private var firstRun:Boolean = true;
private var readysetgo:Boolean = true;

[Bindable] private var temperatureLevel:Number = 500;
[Bindable] private var tempTable:Dictionary = new Dictionary();
[Bindable] private var videoSource:String;
[Bindable] private var videoSource2:String;
[Bindable] private var countDownText:String = "READY..";
[Bindable] private var maxReadVal:Number = 500;
[Bindable] private var minReadVal:Number = 500;

private var process:NativeProcess;
private var nativeProcessStartupInfo:NativeProcessStartupInfo

private var countingUp:Boolean = false;
private var countingDown:Boolean = false;

private var instructionInterval:Number;

private var gameTimer:Timer;

private const WARMING_TEXT:String = "                                              Varme flyttes fra utsiden (jord, luft eller vann) av huset til innsiden av huset.                                              Du varierer trykket i ulike deler av varmepumpa.                                              I en varmepumpe veksler det derfor mellom væske og gass.                                              Fordampning krever energi og kondensering avgir energi.";
private const COOLING_TEXT:String = "                                              Varme flyttes fra innsiden av huset til utsiden av huset.                                              Du varierer trykket i ulike deler av varmepumpa.                                              I en varmepumpe veksler det derfor mellom væske og gass.                                              Fordampning krever energi og kondensering avgir energi.                                              Et kjøleskap er en varmepumpe.";

protected function initApp(event:FlexEvent):void {
	this.stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
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
	
	gameTimer = new Timer(COUNTDOWN_INTERVAL,0);
	gameTimer.addEventListener(TimerEvent.TIMER, timeGame);
	
	process.start(nativeProcessStartupInfo);
	
	videoSource2 = "assets/vids/hp.mp4";
	videoSource = "assets/vids/hpf.mp4";
}

public function onOutputData(event:ProgressEvent):void
{
	try {
		lastReadData = Number(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
		if(firstRun) {
			INITIAL_REFERENCE_VALUE = temperatureLevel = lastReadData;
			firstRun = false;
		}
		else if(this.currentState == "game")
			sensorUpdate();
		else
			stateChanger();
	}
	catch(e:Error) {
		if(e.errorID == 2030) {
			process.exit();
			process.start(nativeProcessStartupInfo);
		}
		return;
	}
}

private function timeGame(event:TimerEvent):void {
	if(readysetgo) {
		if(countDownText == "GO!") {
			videoPlayer.visible = true;
			videoPlayer2.visible = false;
			countDown.visible = false;
			readysetgo = false;
			gameTimer.reset();
			gameTimer.delay = MONTH_INTERVAL;
			gameTimer.repeatCount = MONTH_COUNTS;
			gameTimer.addEventListener(TimerEvent.TIMER_COMPLETE, stopGame);
			gameTimer.start();
		}
		else {
			if(countDownText == "READY..")
				countDownText = "SET..";
			else if(countDownText == "SET..") {
				countDownText = "GO!";
				countDownFadeOut.play();
			}
		}
	}
	// During the game, the house is made to slide acrosss the screen as the months progress. The seasonalOffset is a temperature value (in pixels) updated correspondingly 
	else {
		TweenLite.to(houseImage, 0.5, {x:houseImage.x+100});
		seasonalOffset = int(130*Math.cos(Math.PI*gameTimer.currentCount/6));
		//seasonalOffset = 0;
	}
}

private function stopGame(event:TimerEvent):void {
	gameTimer.reset();
	gameTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, stopGame);
	gameTimer.delay = COUNTDOWN_INTERVAL;
	gameTimer.repeatCount = 0;
	readysetgo = true;
	countDownText = "READY..";
	this.currentState = "result";
	gameStateReady = false;
}

private function restartGame(event:MouseEvent):void {
	this.currentState = "game";
	swfHP.Temp.tHus.y = 75 + (int((INITIAL_REFERENCE_VALUE - lastReadData)*167.5/70));
	//	swfHP.Temp.tOut.tempOutText.fontSize = 10;
	houseImage.x = 350;
	swfHP.mv_default.visible = true;
	swfHP.mv_red.visible = false;
	swfHP.mv_blue.visible = false;
	countDown.visible = true;
	gameTimer.start();
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

private function stateChanger():void {
	
	if(lastReadData > maxReadVal) {
		maxReadVal = lastReadData;
	}
	
	if(lastReadData < minReadVal && lastReadData != 0) {
		minReadVal = lastReadData;
	}
	
	switch(this.currentState) {
		case "welcome":
			if(lastReadData > HIGH_LIMIT || lastReadData < LOW_LIMIT) {
				this.currentState = "instruction";
				// Allows enough time for crank to settle, else may change to game state too early 
				instructionInterval = setInterval(function():void {gameStateReady = true;}, INSTRUCTION_INTERVAL);
			}
			break;
		case "instruction":
			if(gameStateReady && lastReadData > HIGH_LIMIT || lastReadData < LOW_LIMIT) {
				this.currentState = "game";
				swfHP.Temp.tHus.y = 75 + (int((INITIAL_REFERENCE_VALUE - lastReadData)*167.5/70));
			//	swfHP.Temp.tOut.tempOutText.fontSize = 10;
				houseImage.x = 350;
				swfHP.mv_default.visible = true;
				swfHP.mv_red.visible = false;
				swfHP.mv_blue.visible = false;
				countDown.visible = true;
				gameTimer.start();
			}
			break;
		case "result":
			break;
	}
}

private function sensorUpdate():void {
	if(lastReadData > HIGH_LIMIT_GAME) {
		swfHP.mv_default.visible = false;
		swfHP.mv_red.visible = true;
		swfHP.mv_blue.visible = false;
		videoPlayer.visible = true;
		videoPlayer2.visible = false;
	}
	else if(lastReadData < LOW_LIMIT_GAME) {
		swfHP.mv_default.visible = false;
		swfHP.mv_red.visible = false;
		swfHP.mv_blue.visible = true;
		videoPlayer2.visible = true;
		videoPlayer.visible = false;
	}
	else {
		swfHP.mv_default.visible = true;
		swfHP.mv_red.visible = false;
		swfHP.mv_blue.visible = false;
		videoPlayer2.visible = false;
		videoPlayer.visible = false;
	}
	// 13 pixels per degree,  +-140 realistic readout range from Phidget for 0 to Max handle cranking
	tempVal.text = String(5 - int((INITIAL_REFERENCE_VALUE - lastReadData)*13/70 + seasonalOffset/7));
	swfHP.Temp.tHus.tempHusText.text = tempVal.text;
	swfHP.Temp.tOut.tempOutText.text = String(5 - int(seasonalOffset/7));
	// +-167.5 pixel range from half way point on thermometer, 126 pixels is the half way mark (when added to initial 75)  
	// swfHP.Temp.tHus.y = 75 + (int((INITIAL_REFERENCE_VALUE - lastReadData)*167.5/140)) - 126 + seasonalOffset;
	TweenLite.to(swfHP.Temp.tHus, 0.2, {y:75 + (int((INITIAL_REFERENCE_VALUE - lastReadData)*167.5/70)) - 126 + seasonalOffset});
	TweenLite.to(swfHP.Temp.tOut, 0.2, {y:75 - 126 + seasonalOffset});
}

