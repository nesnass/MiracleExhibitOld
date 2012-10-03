import avmplus.getQualifiedClassName;

import com.daveoncode.logging.LogFileTarget;
import com.greensock.TweenLite;
import com.greensock.easing.*;
import com.phidgets.PhidgetInterfaceKit;
import com.phidgets.events.PhidgetDataEvent;
import com.phidgets.events.PhidgetEvent;

import fl.motion.Color;

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

import mx.charts.BarChart;
import mx.charts.CategoryAxis;
import mx.charts.ColumnChart;
import mx.charts.Legend;
import mx.charts.LinearAxis;
import mx.charts.series.BarSeries;
import mx.charts.series.BarSet;
import mx.charts.series.ColumnSeries;
import mx.charts.series.ColumnSet;
import mx.collections.ArrayCollection;
import mx.collections.ArrayList;
import mx.events.FlexEvent;
import mx.logging.ILogger;
import mx.logging.Log;
import mx.logging.LogEventLevel;
import mx.managers.CursorManager;

private var phid:PhidgetInterfaceKit;
private var lastReadData:Number;
private var resetInterval:Number;
private var seasonalOffset:Number = START_TEMP;
private var monthCounter:uint = 0;
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
private const PIXELS_PER_DEGREE:uint = 10;
private const START_TEMP:int = -2;
private var VALUE_STEP:Number = 3;
private const GAME_INTERVAL:uint = 750; // Milliseconds per step
private const GAME_COUNTS:uint = 52;     // Number of steps
private const COUNTDOWN_INTERVAL:uint = 2000;
private const COUNTDOWN_SECONDS:uint = 3;
private const INSTRUCTION_INTERVAL:uint = 4000;
private const MIN_HOUSE_THERMO:int = -7;
private const MAX_HOUSE_THERMO:int = 40;
private const COMFY_MIN_HOUSE_THERMO:int = 15;
private const COMFY_MAX_HOUSE_THERMO:int = 21;
private var gameStateReady:Boolean = false;
private var firstRun:Boolean = true;
private var readysetgo:Boolean = true;

private var tempTable:Dictionary = new Dictionary();
private var gameTable:Dictionary = new Dictionary();
private var resultTable:Dictionary = new Dictionary();
private var tHusBGColour:Color = new Color();

[Bindable] private var temperatureLevel:Number = 500;
[Bindable] private var videoSource:String;
[Bindable] private var videoSource2:String;
[Bindable] private var countDownText:String = "READY..";

// [Bindable] private var tempHusText:String = String(seasonalOffset);

private var process:NativeProcess;
private var nativeProcessStartupInfo:NativeProcessStartupInfo

private var countingUp:Boolean = false;
private var countingDown:Boolean = false;
private var tempLevel:uint;
private var instructionInterval:Number;

private var gameTimer:Timer;

private const WARMING_TEXT:String = "                                              Varme flyttes fra utsiden (jord, luft eller vann) av huset til innsiden av huset.                                              Du varierer trykket i ulike deler av varmepumpa.                                              I en varmepumpe veksler det derfor mellom væske og gass.                                              Fordampning krever energi og kondensering avgir energi.";
private const COOLING_TEXT:String = "                                              Varme flyttes fra innsiden av huset til utsiden av huset.                                              Du varierer trykket i ulike deler av varmepumpa.                                              I en varmepumpe veksler det derfor mellom væske og gass.                                              Fordampning krever energi og kondensering avgir energi.                                              Et kjøleskap er en varmepumpe.";

private var monthNames:ArrayCollection = new ArrayCollection(["July","August","September","October","November","December","January","February","March","April","May","June"]);
private var monthlyTotals:Object = {month:"January", score:0, sourceEnergyTransferred:0, crankEnergy:0, outdoorTemp:0};
[Bindable]
//private var yearlyData:ArrayCollection = new ArrayCollection();
private var yearlyData:ArrayCollection = new ArrayCollection([
	{month:"January", score:0, sourceEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"February", score:0, sourceEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"March", score:0, sourceEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"April", score:0, sourceEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"May", score:0, sourceEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"June", score:200, sourceEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"July", score:0, sourceEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"August", score:0, sourceEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"September", score:0, sourceEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"October", score:0, sourceEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"November", score:0, sourceEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"December", score:0, sourceEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0}
]);


protected function initApp(event:FlexEvent):void {
	this.stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
	setupAndLaunch();
}


private function setupChart():void {
	columnChart.dataProvider = yearlyData;
	columnChart.showDataTips = false;
	columnChart.percentWidth=100;
	columnChart.percentHeight=100;
	
	var hAxis:CategoryAxis = new CategoryAxis();
	hAxis.categoryField = "month";
	var vAxis:LinearAxis = new LinearAxis();
	vAxis.autoAdjust = true;
	
	columnChart.horizontalAxis = hAxis;
	columnChart.verticalAxis = vAxis;
	
	//	var mySeries:Array = new Array();
	
	var outerSet:ColumnSet = new ColumnSet();
	outerSet.type = "clustered";
	var series1:ColumnSeries = new ColumnSeries();
	series1.yField = "sourceEnergyTransferred";
	series1.xField = "month";
	//	series1.displayName = "score";
	outerSet.series = [series1];
	
	var innerSet:ColumnSet = new ColumnSet();
	innerSet.type = "stacked";
	var series2:ColumnSeries = new ColumnSeries();
	var series3:ColumnSeries = new ColumnSeries();
	series2.yField = "sourceEnergyTransferred";
	series2.xField = "month";
	series2.displayName = "Source Energy";
	series3.yField = "crankEnergy";
	series3.xField = "month";
	series3.displayName = "Crank Energy";
	innerSet.series = [series2, series3];
	
	//	columnChart.series = [outerSet, innerSet];
	columnChart.series = [outerSet];
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
	
	//this.currentState="game";
}

// Configure tables that correspond months and raw data to temperature levels
private function setupTables():void
{
	// Phidget data values corresponding to equivalent Temperature level
	var counter:Number;
	VALUE_STEP = 5;
	tempTable[INITIAL_REFERENCE_VALUE] = 0;
	
	// Set table to contain 50 degrees in either direction
	for(counter=0.5; counter<51; counter+=0.5) {
		tempTable[INITIAL_REFERENCE_VALUE + VALUE_STEP*counter] = counter;
		tempTable[INITIAL_REFERENCE_VALUE - VALUE_STEP*counter] = -counter;
	}
	
	LOW_LIMIT = INITIAL_REFERENCE_VALUE - VALUE_STEP * 7;
	HIGH_LIMIT = INITIAL_REFERENCE_VALUE + VALUE_STEP * 7;
	
	LOW_LIMIT_GAME = INITIAL_REFERENCE_VALUE - VALUE_STEP * 2;
	HIGH_LIMIT_GAME = INITIAL_REFERENCE_VALUE + VALUE_STEP * 2;
	
	// Corresponds month value to the average outdoor temperature at that month, and used to store results
	// Month 1 = Jul
	
	// Populate sourceTable with a basic cosine wave which determines the external temperature over the year
	for(counter=1; counter<GAME_COUNTS+1; counter++) {
		gameTable[counter] = int(18*Math.cos(2*Math.PI*counter/GAME_COUNTS + Math.PI) + 15);
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
			trace("error: "+e.errorID);
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
		//	timeChart.graphics.moveTo(0,100);
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
		var tempLevel:uint = int((lastReadData - INITIAL_REFERENCE_VALUE) / VALUE_STEP)*VALUE_STEP + INITIAL_REFERENCE_VALUE;
		
		
		seasonalOffset = gameTable[gameTimer.currentCount];
		monthCounter += 1;
		
		//yearlyData Format: {month:"January", score:120, sourceEnergyTransferred:45, crankEnergy:102, outdoorTemp:23}
		if(monthCounter % 4 == 0) {
			var update:Object = yearlyData.getItemAt(monthCounter/4 -1);
			update.sourceEnergyTransferred = monthlyTotals.sourceEnergyTransferred/4; 
			yearlyData.setItemAt(update, monthCounter/4 -1);
			// addItem({month:monthNames.getItemAt(monthCounter/4 -1), score:0, sourceEnergyTransferred:monthlyTotals.sourceEnergyTransferred/4 });
			monthlyTotals.sourceEnergyTransferred = 0;
		}
		else {
			// This is the temperature difference between inside and outside, should be multiplied over time to obtain energy. 
			monthlyTotals.sourceEnergyTransferred +=  tempTable[tempLevel];
			// In reality the crank energy will be constant, but over time more cranking is done in colder/hotter months
			// monthlyTotals.crankEnergy = 1000*7;
		}
		// 13 pixels per degree. 75px is the 0 degree point on thermometer graphic.  +-140 realistic readout range from Phidget for 0 to Max handle cranking
		swfHP.Temp.tOut.tempOutText.text = String(seasonalOffset);
		TweenLite.to(swfHP.Temp.tOut, GAME_INTERVAL/1000, {y:75 - seasonalOffset*PIXELS_PER_DEGREE, ease:Linear.easeNone});

		if(COMFY_MIN_HOUSE_THERMO < (tempTable[tempLevel] + seasonalOffset) && (tempTable[tempLevel] + seasonalOffset) < COMFY_MAX_HOUSE_THERMO)
			timeChart.graphics.beginFill(0x00FF00);
			//		timeChart.graphics.lineStyle(10,0x00FF00);
		else
			timeChart.graphics.beginFill(0xFFF000);
	//		timeChart.graphics.lineStyle(10,0xFFF000);
	//	timeChart.graphics.drawRect( lineTo(houseImage.x+25 - 300, 100);
		timeChart.graphics.drawRect(houseImage.x - 280,0,25,15);
			
	//	timeChart.graphics.lineTo(houseImage.x+25 - 300, 100);
		
		TweenLite.to(houseImage, GAME_INTERVAL/1000, {x:houseImage.x+25, ease:Linear.easeNone});
		
	}
}

// Clean up and reset variables when game is completed
private function stopGame(event:TimerEvent):void {
	gameTimer.reset();
	gameTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, stopGame);
	gameTimer.delay = COUNTDOWN_INTERVAL;
	gameTimer.repeatCount = 0;
	monthCounter = 0;
	readysetgo = true;
	countDownText = "READY..";
	//	this.currentState = "result";
	gameStateReady = false;
}

// A button handler allowing the game to be started over again
private function restartGame(event:MouseEvent):void {
	this.currentState = "game";
	swfHP.Temp.tHus.y = 75 + (int((INITIAL_REFERENCE_VALUE - lastReadData)*167.5/70));
	houseImage.x = 280;
	monthCounter = 0;
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
//				setupChart();
				swfHP.Temp.tHus.y = 75;
				swfHP.Temp.tOut.y = 75 - PIXELS_PER_DEGREE*START_TEMP;
				swfHP.Temp.tOut.tempOutText.text = String(seasonalOffset);
		//		houseImage.x = PIXELS_PER_DEGREE*START_TEMP;
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
	tempLevel = int((lastReadData - INITIAL_REFERENCE_VALUE) / VALUE_STEP)*VALUE_STEP + INITIAL_REFERENCE_VALUE;
	
	if(MIN_HOUSE_THERMO < (tempTable[tempLevel] + seasonalOffset) && (tempTable[tempLevel] + seasonalOffset) < MAX_HOUSE_THERMO) {
	
		// House temp reading calculated here from tempTable, accounting for outdoor offset
		// 13 pixels per degree. 75px is the 0 degree point on thermometer graphic.  +-140 realistic readout range from Phidget for 0 to Max handle cranking
		swfHP.Temp.tHus.tempHusText.text = String(tempTable[tempLevel] + seasonalOffset);
		TweenLite.to(swfHP.Temp.tHus, GAME_INTERVAL/1000, {y:75 - (tempTable[tempLevel] + seasonalOffset)*PIXELS_PER_DEGREE, ease:Linear.easeNone});
		if(COMFY_MIN_HOUSE_THERMO < (tempTable[tempLevel] + seasonalOffset) && (tempTable[tempLevel] + seasonalOffset) < COMFY_MAX_HOUSE_THERMO) {
			tHusBGColour.brightness = 0;
		}
		else
			tHusBGColour.brightness = -1;
		swfHP.Temp.tHus.tHusBG.transform.colorTransform = tHusBGColour;
	}
}

