import avmplus.getQualifiedClassName;

import com.daveoncode.logging.LogFileTarget;
import com.greensock.TweenLite;
import com.greensock.easing.*;
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
import flash.system.Capabilities;
import flash.system.System;
import flash.ui.Mouse;
import flash.utils.Dictionary;
import flash.utils.Timer;
import flash.utils.clearInterval;
import flash.utils.getTimer;
import flash.utils.setInterval;

import mx.events.FlexEvent;
import mx.logging.ILogger;
import mx.logging.Log;
import mx.logging.LogEventLevel;
import mx.managers.CursorManager;

private var phid:PhidgetInterfaceKit;
private var lastReadData:Number;
private var resetInterval:Number;
private var seasonalOffset:Number = 24;
private var LOW_LIMIT:uint = 480;
private var HIGH_LIMIT:uint = 520;
private var LOW_LIMIT_GAME:uint = 486;
private var HIGH_LIMIT_GAME:uint = 514;
private var CRANK_SENSITIVITY:uint = 2;
private var INITIAL_REFERENCE_VALUE:uint = 500;
private var TEMP_TO_REFERENCE_RATIO:Number = 0.1;
private const RESET_INTERVAL_VALUE:uint = 15000;
private const STEP_TIME:uint = 250;
private const PIXEL_INCREMENT:uint = 7;
private var VALUE_STEP:uint = 3;
private const GAME_INTERVAL:uint = 500; // Milliseconds per step
private const GAME_COUNTS:uint = 52;     // Number of steps
private const COUNTDOWN_INTERVAL:uint = 2000;
private const COUNTDOWN_SECONDS:uint = 3;
private const INSTRUCTION_INTERVAL:uint = 4000;
private var gameStateReady:Boolean = false;
private var firstRun:Boolean = true;
private var readysetgo:Boolean = true;

private var tempTable:Dictionary = new Dictionary();
private var gameTable:Dictionary = new Dictionary();

[Bindable] private var temperatureLevel:Number = 500;
[Bindable] private var videoSource:String;
[Bindable] private var videoSource2:String;
[Bindable] private var countDownText:String = "READY..";

// [Bindable] private var tempHusText:String = String(seasonalOffset);

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

// Initial setup of Phidget controller & game timer
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

// Configure tables that correspond months and raw data to temperature levels
private function setupTables():void
{
	// Phidget data values corresponding to equivalent Temperature level
	var counter:uint;
	VALUE_STEP = 3;
	tempTable[INITIAL_REFERENCE_VALUE] = 0;
	
	// Set table to contain 50 degrees in either direction
	for(counter=1; counter<51; counter++) {
		tempTable[INITIAL_REFERENCE_VALUE + VALUE_STEP*counter] = counter;
		tempTable[INITIAL_REFERENCE_VALUE - VALUE_STEP*counter] = -counter;
	}
	
	LOW_LIMIT = INITIAL_REFERENCE_VALUE - VALUE_STEP * 7;
	HIGH_LIMIT = INITIAL_REFERENCE_VALUE + VALUE_STEP * 7;
	
	LOW_LIMIT_GAME = INITIAL_REFERENCE_VALUE - VALUE_STEP * 5;
	HIGH_LIMIT_GAME = INITIAL_REFERENCE_VALUE + VALUE_STEP * 5;
	
	// Corresponds month value to the average outdoor temperature at that month, and used to store results
	// Month 1 = Jul
	
	// Populate sourceTable which determines the external temperature over the year
	for(counter=1; counter<GAME_COUNTS+1; counter++) {
		gameTable[counter] = int(15*Math.cos(2*Math.PI*counter/GAME_COUNTS) + 10);
	}

}

// Reads raw data from the Phidget device when a data output event occurrs
public function onOutputData(event:ProgressEvent):void
{
	try {
		lastReadData = Number(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
		if(firstRun) {
			INITIAL_REFERENCE_VALUE = temperatureLevel = lastReadData;
			setupTables();
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

// The method called to manage timer events :  First the count down, then the month change and statistic recording
private function timeGame(event:TimerEvent):void {
	if(readysetgo) {
		if(countDownText == "GO!") {
		//	videoPlayer.visible = true;
		//	videoPlayer2.visible = false;
			countDown.visible = false;
			readysetgo = false;
			gameTimer.reset();
			gameTimer.delay = GAME_INTERVAL;
			gameTimer.repeatCount = GAME_COUNTS-1;
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
	// During the game, the house is made to slide acrosss the screen as the months progress. 
	// seasonalOffset is a temperature value (in pixels) updated correspondingly
	// Source input slider slowly moves up and down in accordance with the season
	else {
		TweenLite.to(houseImage, 0.5, {x:houseImage.x+25, ease:Linear.easeNone});
		seasonalOffset = gameTable[gameTimer.currentCount];
		
		// 13 pixels per degree. 75px is the 0 degree point on thermometer graphic.  +-140 realistic readout range from Phidget for 0 to Max handle cranking
		swfHP.Temp.tOut.tempOutText.text = String(seasonalOffset);
		TweenLite.to(swfHP.Temp.tOut, GAME_INTERVAL/1000, {y:75 - seasonalOffset*13, ease:Linear.easeNone});
		
		// At this point record game stats...
		
	}
}

// Clean up and reset variables when game is completed
private function stopGame(event:TimerEvent):void {
	gameTimer.reset();
	gameTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, stopGame);
	gameTimer.delay = COUNTDOWN_INTERVAL;
	gameTimer.repeatCount = 0;
	readysetgo = true;
	countDownText = "READY..";
	//	this.currentState = "result";
	gameStateReady = false;
}

// A button handler allowing the game to be started over again
private function restartGame(event:MouseEvent):void {
	this.currentState = "game";
	swfHP.Temp.tHus.y = 75 + (int((INITIAL_REFERENCE_VALUE - lastReadData)*167.5/70));
	houseImage.x = 300;
	swfHP.mv_default.visible = true;
	swfHP.mv_red.visible = false;
	swfHP.mv_blue.visible = false;
	countDown.visible = true;
	countDown.alpha = 1;
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

// Manage transition through Intro, Instruction, Game and Stats pages
private function stateChanger():void {
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
				swfHP.Temp.tHus.y = 75 - 312;
				swfHP.Temp.tOut.y = 75 - 312;
				swfHP.Temp.tOut.tempOutText.text = String(seasonalOffset);
				houseImage.x = 300;
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

// Called during game play, each time a sensor vale is given
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

	// Normalise the read value to match a table value
	var tempLevel:uint = int((lastReadData - INITIAL_REFERENCE_VALUE) / VALUE_STEP)*VALUE_STEP + INITIAL_REFERENCE_VALUE;

	// House temp reading calculated here from tempTable, accounting for outdoor offset
	// 13 pixels per degree. 75px is the 0 degree point on thermometer graphic.  +-140 realistic readout range from Phidget for 0 to Max handle cranking
	swfHP.Temp.tHus.tempHusText.text = String(tempTable[tempLevel] + seasonalOffset);
	TweenLite.to(swfHP.Temp.tHus, GAME_INTERVAL/1000, {y:75 - tempTable[tempLevel]*13 - seasonalOffset*13, ease:Linear.easeNone});
	// trace(flash.utils.getTimer());
}

