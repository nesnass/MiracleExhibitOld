import avmplus.getQualifiedClassName;

import com.greensock.TweenLite;
import com.greensock.easing.*;
import com.phidgets.PhidgetInterfaceKit;
import com.phidgets.events.*;

import fl.motion.*;
import fl.motion.Color;

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.display.Loader;
import flash.display.Sprite;
import flash.display.StageDisplayState;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.MouseEvent;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;
import flash.events.TimerEvent;
import flash.filesystem.File;
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.net.URLRequest;
import flash.net.dns.AAAARecord;
import flash.system.Capabilities;
import flash.system.System;
import flash.ui.Mouse;
import flash.utils.Dictionary;
import flash.utils.Timer;
import flash.utils.clearInterval;
import flash.utils.getTimer;
import flash.utils.setInterval;

import mx.charts.AreaChart;
import mx.charts.AxisRenderer;
import mx.charts.BarChart;
import mx.charts.CategoryAxis;
import mx.charts.GridLines;
import mx.charts.Legend;
import mx.charts.LinearAxis;
import mx.charts.series.AreaSeries;
import mx.charts.series.AreaSet;
import mx.charts.series.BarSeries;
import mx.charts.series.BarSet;
import mx.charts.series.ColumnSeries;
import mx.charts.series.ColumnSet;
import mx.collections.ArrayCollection;
import mx.collections.ArrayList;
import mx.core.UIComponent;
import mx.events.FlexEvent;
import mx.graphics.GradientEntry;
import mx.graphics.LinearGradient;
import mx.graphics.SolidColor;
import mx.logging.ILogger;
import mx.logging.Log;
import mx.logging.LogEventLevel;
import mx.managers.CursorManager;

public var phid:PhidgetInterfaceKit = new PhidgetInterfaceKit();

private var lastReadData:int;
private var tempAverage:int = 0;
private var seasonalTemperature:Number = -3;
private var monthCounter:uint = 0;
private var LOW_LIMIT:uint = 480;
private var HIGH_LIMIT:uint = 520;
private var LOW_LIMIT_GAME:uint = 486;
private var HIGH_LIMIT_GAME:uint = 514;
private var INITIAL_REFERENCE_VALUE:uint = 500;
private var VALUE_STEP:uint = 5; // How many read values per change in temperature
private var DEGREE_RANGE:uint = 60; // Temperature range to be used in either direction 
private const MIN_HOUSE_THERMO:int = -7;
private const MAX_HOUSE_THERMO:int = 40;
private const COMFY_MIN_HOUSE_THERMO:int = 15;
private const COMFY_MAX_HOUSE_THERMO:int = 21;
private const GAME_START_OFFSET:uint = 65;
private const PIXELS_PER_DEGREE:uint = 60;
private const LARGE_PIXELS_PER_DEGREE:uint = 120;
private const tempMarksBG_Y:int = -1995;
private const tempMarks_Y:int = -4420;
private const GAME_COUNTS:uint = 96;     // Number of steps (eight samples per month)
private const COUNTDOWN_INTERVAL:uint = 1800;
//private const COUNTDOWN_INTERVAL:uint = 500;
private const GAME_INTERVAL:uint = 375; // Milliseconds per step
//private const GAME_INTERVAL:uint = 100;

private var firstRun:Boolean = true;
private var readysetgo:Boolean = true;
private var sampleInterval:uint;
private var crossSpeed:Number = 0;
private var cross:Loader = new Loader();
private var ptRotationPoint:Point;
private var rotator:Rotator;
private var myLegend:Legend = new Legend();
private var tempTable:Dictionary = new Dictionary();  // Matches sensor read values to temperature values
private var seasonalTempTable:Dictionary = new Dictionary();  // Matches the current game sample point to the current seasonal outdoor temperature

[Bindable] private var videoSource:String;
[Bindable] private var videoSource2:String;
[Bindable] private var countDownText:String = "3..";

[Embed(source="assets/fonts/Franklin Gothic Demi.ttf", fontFamily="Franklin Gothic Demi", fontName="FGD", mimeType="application/x-font-truetype")]
private static var Fontclass1:Class;

//private var process:NativeProcess;
//private var nativeProcessStartupInfo:NativeProcessStartupInfo
private var tempLevel:uint;
private var tHusBGColour:Color = new Color();
private var gameTimer:Timer;

private var testTimer:Timer;

private var tempAveragingArray:Array = new Array(20);

// private var monthNames:ArrayCollection = new ArrayCollection(["July","August","September","October","November","December","January","February","March","April","May","June"]);
private var monthlyTotals:Object = {month:"January", score:0, sourceEnergyTransferred:0, idealEnergyTransferred:0, crankEnergy:0, outdoorTemp:0};

// Store the results of the game for each month
[Bindable]
/*
private var yearlyData:ArrayCollection = new ArrayCollection([
	{month:"Winter", score:0, sourceEnergyTransferred:0, idealEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"Spring", score:0, sourceEnergyTransferred:0, idealEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"Summer", score:0, sourceEnergyTransferred:0, idealEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"Autumn", score:0, sourceEnergyTransferred:0, idealEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0}
]);
*/
private var yearlyData:ArrayCollection = new ArrayCollection([
	{month:"January", score:0, sourceEnergyTransferred:0, idealEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"February", score:0, sourceEnergyTransferred:0, idealEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"March", score:0, sourceEnergyTransferred:0, idealEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"April", score:0, sourceEnergyTransferred:0, idealEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"May", score:0, sourceEnergyTransferred:0, idealEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"June", score:200, sourceEnergyTransferred:0, idealEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"July", score:0, sourceEnergyTransferred:0, idealEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"August", score:0, sourceEnergyTransferred:0, idealEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"September", score:0, sourceEnergyTransferred:0, idealEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"October", score:0, sourceEnergyTransferred:0, idealEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"November", score:0, sourceEnergyTransferred:0, idealEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0},
	{month:"December", score:0, sourceEnergyTransferred:0, idealEnergyTransferred:0,
		crankEnergy:0, outdoorTemp:0}
]);

protected function initApp(event:FlexEvent):void {
	this.stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
	setupAndLaunch();
}

// Create the chart specifics to display game result
private function setupChart():void {
	areaChart.dataProvider = yearlyData;
	areaChart.showDataTips = false;
	areaChart.percentWidth=100;
	areaChart.percentHeight=100;

	var ge1:GradientEntry = new GradientEntry(0xFF0000, 0, 1);
	var ge2:GradientEntry = new GradientEntry(0xFF5500, 0.33, 1);
	var ge3:GradientEntry = new GradientEntry(0xFF9900, 0.66, 1);

	var ge4:GradientEntry = new GradientEntry(0x0000FF, 0, 1);
	var ge5:GradientEntry = new GradientEntry(0x0055FF, 0.33, 1);
	var ge6:GradientEntry = new GradientEntry(0x0099FF, 0.66, 1);
	
	var lg1entries:Array = [ge1,ge2,ge3];
	var lg2entries:Array = [ge4,ge5,ge6];
	
	var lg1:LinearGradient = new LinearGradient();
	lg1.entries = lg1entries;
	var lg2:LinearGradient = new LinearGradient();
	lg2.entries = lg2entries;
	
	var gl:GridLines = new GridLines();
	//gl.setStyle("gridDirection", "both");
	gl.setStyle("horizontalTickAligned", true);
	gl.setStyle("horizontalChangeCount", 2);
	
	var bge:Array = new Array();
	bge.push(gl);
	
	var hAxis:CategoryAxis = new CategoryAxis();
	hAxis.categoryField = "month";
	var hAxisRenderer:AxisRenderer = new AxisRenderer();
	hAxisRenderer.axis = hAxis;
	hAxisRenderer.setStyle("showLabels", false);
	hAxisRenderer.setStyle("tickPlacement", "none");
	
	var vAxis:LinearAxis = new LinearAxis();
	vAxis.autoAdjust = true;
	var vAxisRenderer:AxisRenderer = new AxisRenderer();
	vAxisRenderer.axis = vAxis;
	vAxisRenderer.setStyle("showLabels", false);
	vAxisRenderer.setStyle("tickPlacement", "none");
	vAxisRenderer.setStyle("showLine", false);
	
	areaChart.verticalAxisRenderers = [vAxisRenderer];
	areaChart.horizontalAxisRenderers = [hAxisRenderer];
	
	areaChart.horizontalAxis = hAxis;
	areaChart.verticalAxis = vAxis;
	areaChart.backgroundElements = bge;

	var innerSet:AreaSet = new AreaSet();
	innerSet.type = "clustered";
	
	var series1:AreaSeries = new AreaSeries();
	series1.setStyle("fill", 0xF9BE10);
	series1.yField = "idealEnergyTransferred";
	series1.xField = "month";
	series1.displayName = "Energy Required";
	
	var fillColor1:SolidColor = new SolidColor();
	fillColor1.color = 0x99CC33;
	var fillColor2:SolidColor = new SolidColor();
	fillColor2.color = 0xC9D52E;
	
	var series2:AreaSeries = new AreaSeries();
	series2.setStyle("areaFill", fillColor1);
	series2.yField = "sourceEnergyTransferred";
	series2.xField = "month";
	series2.displayName = "Energi overført mellom inne og ute";
	series2.setStyle("form", "curve");
	
	var series3:AreaSeries = new AreaSeries();
	series3.setStyle("areaFill", fillColor2);
	series3.yField = "crankEnergy";
	series3.xField = "month";
	series3.displayName = "Energi brukt for å drive varmepumpa";
	series3.setStyle("form", "curve");
	
	innerSet.series = [series2, series3];
	
	//	areaChart.series = [outerSet, innerSet];
	areaChart.series = [innerSet];
	areaChart.maxWidth = 1070;
	areaChart.maxHeight = 200;
	
	//myLegend.dataProvider = areaChart;
	//if(!legend.contains(myLegend))
	//	legend.addChild(myLegend);
	
	var totalScore:int = 0;
	var totalEnergyTransferred:Number = 0;
	var totalCrankEnergy:Number = 0;
	
	for each(var o:Object in yearlyData) {
		totalScore += o.score;
		totalEnergyTransferred += o.sourceEnergyTransferred;
		totalCrankEnergy += o.crankEnergy;
	}
	totalScore = 100*totalScore/GAME_COUNTS;
	hpFinish.endText.visible = false;
	hpFinish.guageFinishGroup.scoreFinish.score.scoreTxt.text = String(totalScore) + "%";
	hpFinish.guageFinishGroup.guageArrow.rotation = -90;
	hpFinish.guageFinishGroup.scaleX = 1.5;
	hpFinish.guageFinishGroup.scaleY = 1.5;
	hpFinish.guageFinishGroup.y = 800;
	
	hpFinish.endText.txt.text = "Prøv å holde temperaturen mer stabilt"+'\n'+"for å forbedre resultatet!"+'\n'+'\n'
		+"I løpet av året brukte du "+Math.abs(int(totalEnergyTransferred))+" KW timer. "
		+Math.abs(int(totalCrankEnergy))+" gikk med til å drive varmepumpa, resten ble hentet fra lufta utendørs.";
	// Multiplies by 0.9 to fit the needle into the guage!
	TweenLite.to(hpFinish.guageFinishGroup.guageArrow, 3, {rotation: (1.8*totalScore - 90)*0.9, ease:Bounce.easeOut, onComplete: completeLastScreen});
}

private function completeLastScreen():void {
	TweenLite.to(hpFinish.guageFinishGroup, 3, {y: 500, scaleX: 1, scaleY: 1, ease:Linear.easeNone, onComplete: showChart});
}
private function showChart():void {
	areaChart.visible = true;
	timeChart.visible = true;
	hpFinish.chartLegend.visible = true;
	hpFinish.endText.visible = true;
	
	areaChart.alpha = 0;
	timeChart.alpha = 0;
	hpFinish.chartLegend.alpha = 0;
	hpFinish.endText.alpha = 0;
	
	TweenLite.to(areaChart, 1, {alpha: 1});
	TweenLite.to(timeChart, 1, {alpha: 1});
	TweenLite.to(hpFinish.chartLegend, 1, {alpha: 1});
	TweenLite.to(hpFinish.endText, 1, {alpha: 1});

	//legend.visible = true;
}
private function enterFrame(event:Event):void {
	rotator.rotation += crossSpeed;
}

// Initial setup of Phidget controller & game timer
public function setupAndLaunch():void
{
	gameTimer = new Timer(COUNTDOWN_INTERVAL,0);
	gameTimer.addEventListener(TimerEvent.TIMER, timeGame);
	
	testTimer = new Timer(30000,1);
	testTimer.addEventListener(TimerEvent.TIMER_COMPLETE, testGame);
//	testTimer.start();
	
	phid.open("localhost",5001);
	phid.addEventListener(PhidgetEvent.ATTACH, onAttach);
	
	videoSource2 = "assets/vids/hp.mp4";
	videoSource = "assets/vids/hpf.mp4";
	
//	this.currentState = "result";
//	this.setupChart();
}

private function testGame(event:Event):void {
	hpStart.guageArrow.rotation = 81;
	testTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, testGame);
}

// Configure tables that correspond months with raw data to temperature levels
// +-140 is a realistic readout range from Phidget from none to maximum speed handle cranking
private function setupTables():void
{
	// Phidget data values corresponding to equivalent Temperature level
	var counter:Number;
	tempTable[INITIAL_REFERENCE_VALUE] = 0;
	
	// Set table to contain DEGREE_RANGE degrees in either direction
	for(counter=1; counter<=DEGREE_RANGE; counter+=1) {
		tempTable[INITIAL_REFERENCE_VALUE - VALUE_STEP*counter] = counter;
		tempTable[INITIAL_REFERENCE_VALUE + VALUE_STEP*counter] = -counter;
	}
	
	LOW_LIMIT = INITIAL_REFERENCE_VALUE - VALUE_STEP * 7;
	HIGH_LIMIT = INITIAL_REFERENCE_VALUE + VALUE_STEP * 7;
	
	LOW_LIMIT_GAME = INITIAL_REFERENCE_VALUE - VALUE_STEP * 2;
	HIGH_LIMIT_GAME = INITIAL_REFERENCE_VALUE + VALUE_STEP * 2;
	
	// Populate sourceTable with a basic cosine wave which determines the external temperature over the year
	for(counter=1; counter<=GAME_COUNTS+1; counter++) {
		seasonalTempTable[counter] = int(18*Math.cos(2*Math.PI*counter/GAME_COUNTS + Math.PI) + 15);
	}
}

// The method called to manage timer events :  First the count down, then the month change and statistic recording
private function timeGame(event:TimerEvent):void {
	if(readysetgo) {
		if(countDownText == "3..") {
			countDownText = "2.."
		}
		else if(countDownText == "2..") {
			countDownText = "1..";
		}
		else if(countDownText == "1..") {
			countDownText = "GO!";
			videoGroup.visible = true;
			spriteGroup.visible = true;
			hpGame.arrowFlowL.alpha = 1;
			hpGame.arrowFlowL.alpha = 1;
//			cdwn.visible = false;
//			countDownFadeOut.play();
			hpGame.TEMPERATURE.left_temp_mc.leftMarks.y = tempMarks_Y + seasonalTemperature*LARGE_PIXELS_PER_DEGREE;
			hpGame.TEMPERATURE.left_temp_mc.leftMarksBG.y = tempMarksBG_Y + seasonalTemperature*PIXELS_PER_DEGREE;
			readysetgo = false;
			gameTimer.reset();
			gameTimer.delay = GAME_INTERVAL;
			gameTimer.repeatCount = GAME_COUNTS;
			gameTimer.addEventListener(TimerEvent.TIMER_COMPLETE, stopGame);
			gameTimer.start();
		}
	}
	// During the game, the house is made to slide acrosss the screen as the months progress.
	// seasonalTemperature is a temperature value (in pixels) updated correspondingly
	// Source input slider slowly moves up and down in accordance with the season
	else {
		tempAverage = tempAveragingArray[0]*0.05 + tempAveragingArray[1]*0.05 + tempAveragingArray[2]*0.05 + tempAveragingArray[3]*0.05 + tempAveragingArray[4]*0.05
			+ tempAveragingArray[5]*0.05 + tempAveragingArray[6]*0.05 + tempAveragingArray[7]*0.05 + tempAveragingArray[8]*0.05 + tempAveragingArray[9]*0.05
			+ tempAveragingArray[10]*0.05 + tempAveragingArray[11]*0.05 + tempAveragingArray[12]*0.05 + tempAveragingArray[13]*0.05 + tempAveragingArray[14]*0.05
			+ tempAveragingArray[15]*0.05 + tempAveragingArray[16]*0.05 + tempAveragingArray[17]*0.05 + tempAveragingArray[18]*0.05 + tempAveragingArray[19]*0.05;
		
		// Normalise the read value to match one of the tempTable values
		var tempLevel:int = int((tempAverage - INITIAL_REFERENCE_VALUE) / VALUE_STEP)*VALUE_STEP + INITIAL_REFERENCE_VALUE;
		
		// 10 pixels per degree. 75px is the 0 degree point on thermometer graphic.  +-140 realistic readout range from Phidget for 0 to Max handle cranking
		seasonalTemperature = seasonalTempTable[gameTimer.currentCount];
		//yearlyData Format example: {month:"January", score:120, sourceEnergyTransferred:45, crankEnergy:102, outdoorTemp:23}
		// % value depends on number of GAME_COUNTS - eg. one year has 52 weeks so if collecting data per month, divide by 4
		// At present resolution (therefore GAME_COUNTS) is higher to support a smoother change of Outside temp marker on screen

		monthCounter += 1;
		if((monthCounter > 0 && monthCounter % 8 == 0) || monthCounter == GAME_COUNTS) {
			
			// This is the temperature difference between inside and outside, should be multiplied over time to obtain energy. 
			monthlyTotals.sourceEnergyTransferred +=  tempTable[tempLevel];
			// Temperature difference between outside and +18 degrees, the ideal indoor level
			monthlyTotals.idealEnergyTransferred +=  (18 - seasonalTemperature);
			monthlyTotals.crankEnergy +=  tempTable[tempLevel]/3;
			// In reality the crank energy will be constant, but over time more cranking is done in colder/hotter months
			// monthlyTotals.crankEnergy = 1000*7;
			
			var update:Object = yearlyData.getItemAt(monthCounter/8 -1);
			update.sourceEnergyTransferred = monthlyTotals.sourceEnergyTransferred/8;
			update.idealEnergyTransferred = monthlyTotals.idealEnergyTransferred/8;
			update.score = monthlyTotals.score;
			update.crankEnergy = monthlyTotals.crankEnergy/8;
			yearlyData.setItemAt(update, monthCounter/8 -1);
			
			monthlyTotals.sourceEnergyTransferred = 0;
			monthlyTotals.idealEnergyTransferred = 0;
			monthlyTotals.score = 0;
			monthlyTotals.crankEnergy = 0;
		}
		else {
			monthlyTotals.sourceEnergyTransferred +=  tempTable[tempLevel];
			monthlyTotals.idealEnergyTransferred +=  (18 - seasonalTemperature);
			monthlyTotals.crankEnergy +=  tempTable[tempLevel]/3;
		}
		
		TweenLite.to(hpGame.TEMPERATURE.right_temp_mc.rightMarksBG, GAME_INTERVAL/500, {y: tempMarksBG_Y + seasonalTemperature*PIXELS_PER_DEGREE, ease:Linear.easeNone});
		TweenLite.to(hpGame.TEMPERATURE.right_temp_mc.rightMarks, GAME_INTERVAL/500, {y: tempMarks_Y + seasonalTemperature*LARGE_PIXELS_PER_DEGREE, ease:Linear.easeNone});

		//monthlyTotals.score++;

		if(COMFY_MIN_HOUSE_THERMO <= (tempTable[tempLevel] + seasonalTemperature) && (tempTable[tempLevel] + seasonalTemperature) <= COMFY_MAX_HOUSE_THERMO) {
			timeChart.graphics.beginFill(0x339933);
			monthlyTotals.score++;
		}
		else
			timeChart.graphics.beginFill(0x000000);

		timeChart.graphics.drawRect(timeChart.width/GAME_COUNTS*monthCounter-1,0,timeChart.width/GAME_COUNTS,40);
		timeChart.graphics.endFill();
	}
}

// Clean up and reset variables when game is completed and show results
private function stopGame(event:TimerEvent):void {
	clearInterval(sampleInterval);
	gameTimer.reset();
	gameTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, stopGame);
	gameTimer.addEventListener(TimerEvent.TIMER_COMPLETE, returnFirstScreen);
	gameTimer.removeEventListener(TimerEvent.TIMER, timeGame);
	// Time delay before returning to opening screen
	gameTimer.delay = 25000;
	gameTimer.repeatCount = 1;
	monthCounter = 0;
	readysetgo = true;
	countDownText = "3..";
	this.removeEventListener(Event.ENTER_FRAME, enterFrame);
	videoGroup.visible = false;
	spriteGroup.visible = false;
	videoPlayer2.visible = false;
	videoPlayer.visible = false;
	timeChart.visible = false;
	this.currentState = "result";
	hpFinish.chartLegend.visible = false;
	setupChart();
	gameTimer.start();
}

// Start the game over again
private function returnFirstScreen(event:TimerEvent):void {
	legend.visible = false;
	areaChart.visible = false;
	timeChart.graphics.clear();
	this.currentState = "instruction";
	hpStart.guageArrow.rotation = -80;
	gameTimer.reset();
	gameTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, returnFirstScreen);
	gameTimer.addEventListener(TimerEvent.TIMER, timeGame);
	gameTimer.delay = COUNTDOWN_INTERVAL;
	gameTimer.repeatCount = 0;
//	gameTimer.start();
	sampleInterval = setInterval(takeSample, 100);
	
	testTimer.addEventListener(TimerEvent.TIMER_COMPLETE, testGame);
	testTimer.reset();
//	testTimer.start();
}


public function onAttach(evt:PhidgetEvent):void {
	phid.setSensorChangeTrigger(6, 5);
	sampleInterval = setInterval(takeSample, 100);
}

// Called at the samle rate, takes a sample and determines whether to 
public function takeSample():void {
	lastReadData = phid.getSensorValue(6);
	
	// The first sample is to determine the steady state value
	if(firstRun) {
		INITIAL_REFERENCE_VALUE = lastReadData;
		for(var i:uint=0;i<20;i++)
			tempAveragingArray[i] = INITIAL_REFERENCE_VALUE;
		setupTables();
		firstRun = false;
		hpStart.guageArrow.rotation = -80;
	}
	else if(this.currentState == "game")
		// In game state, use the data to upate the screen graphics
		gameUpdate();
	else
		// In Instruction mode, use the data to run the speedometer, to initiate the game
		introUpdate();
}

private function onInputChange(evt:PhidgetDataEvent):void{
	trace(evt.Index);
	trace(evt.Data);
}


private function onSensorChange(evt:PhidgetDataEvent):void{
	trace(evt);
}


private function onDisconnect(evt:PhidgetEvent):void{
	trace("Disconnected");
}

private function onConnect(evt:PhidgetEvent):void{
	trace("Connected");
//	this.stage.nativeWindow.activate();
//	this.stage.nativeWindow.orderToBack();
//	this.stage.nativeWindow.orderToFront();
//	Mouse.hide();
}

// Updates teh speedo based on accumulation of cranks
private function introUpdate():void {
	tempAverage = int((lastReadData - INITIAL_REFERENCE_VALUE)/10);
	
	if(hpStart.guageArrow.rotation > -80 || tempAverage < 0)
		TweenLite.to(hpStart.guageArrow, 0.15, {rotation: hpStart.guageArrow.rotation - tempAverage});
	
	if(hpStart.guageArrow.rotation > 80) {
		this.currentState = "game";

		var ventLoader:Loader = new Loader();
		ventLoader.load(new URLRequest("assets/pics/vent.png"));
		hpGame.intro_txt.alpha = 1;
		ventOverlay.alpha = 0;
		crossOverlay.alpha = 0;
		
		//cross = new Sprite();

		cross = new Loader();
		cross.load(new URLRequest("assets/pics/crossX.png"));
	//	cross.addChild(crossLoader);

		var crossLoader2:Loader = new Loader();
		crossLoader2.load(new URLRequest("assets/pics/crossBG.png"));
		crossOverlay.addChild(crossLoader2);
		//cross.setupAnimation();

		crossOverlay.addChild(cross);
		ventOverlay.addChild(ventLoader);
		rotator = new Rotator(cross, new Point(65,65));
		this.addEventListener(Event.ENTER_FRAME, enterFrame);
		
		hpGame.heatPump.alpha = 0;
		hpGame.TEMPERATURE.right_temp_mc.rightMarks.y = tempMarks_Y + seasonalTemperature*LARGE_PIXELS_PER_DEGREE;
		hpGame.TEMPERATURE.right_temp_mc.rightMarksBG.y = tempMarksBG_Y + seasonalTemperature*PIXELS_PER_DEGREE;
		hpGame.TEMPERATURE.left_temp_mc.leftMarks.y = tempMarks_Y + 18*LARGE_PIXELS_PER_DEGREE;
		hpGame.TEMPERATURE.left_temp_mc.leftMarksBG.y = tempMarksBG_Y + 18*PIXELS_PER_DEGREE;
		//countDown.visible = true;
		
		// This is the transition efect of the instruction text and pump fade in, before the countdown begins.
		TweenLite.to(hpGame.intro_txt, 10, {alpha: 0, ease:Expo.easeIn, onComplete: function():void {initiateCountdown();}});
	}
}

private function initiateCountdown():void {
	
	TweenLite.to(hpGame.heatPump, 5, {alpha: 1, ease:Linear.easeNone});
	TweenLite.to(crossOverlay, 5, {alpha: 1, ease:Linear.easeNone});
	TweenLite.to(ventOverlay, 5, {alpha: 1, ease:Linear.easeNone});
	
	cdwn.load("assets/flash/countdown.swf");
	cdwn.visible = true;
	cdwn.enabled = true;
	hpGame.arrowFlowL.alpha = 0;
	hpGame.arrowFlowL.alpha = 0;
	gameTimer.start();
}

// Called during game play, each time a sensor vale is given
private function gameUpdate():void {

	tempAveragingArray.shift();
	tempAveragingArray[19] = lastReadData;
	
	// Weighted average aiming to smooth the current temp value
	//	tempAverage = tempAveragingArray[0]*0.05 + tempAveragingArray[1]*0.05 + tempAveragingArray[2]*0.1 
	//				+ tempAveragingArray[3]*0.1 + tempAveragingArray[4]*0.2 + tempAveragingArray[5]*0.5;

	tempAverage = tempAveragingArray[0]*0.05 + tempAveragingArray[1]*0.05 + tempAveragingArray[2]*0.05 + tempAveragingArray[3]*0.05 + tempAveragingArray[4]*0.05
		+ tempAveragingArray[5]*0.05 + tempAveragingArray[6]*0.05 + tempAveragingArray[7]*0.05 + tempAveragingArray[8]*0.05 + tempAveragingArray[9]*0.05
		+ tempAveragingArray[10]*0.05 + tempAveragingArray[11]*0.05 + tempAveragingArray[12]*0.05 + tempAveragingArray[13]*0.05 + tempAveragingArray[14]*0.05
		+ tempAveragingArray[15]*0.05 + tempAveragingArray[16]*0.05 + tempAveragingArray[17]*0.05 + tempAveragingArray[18]*0.05 + tempAveragingArray[19]*0.05;
	
	if(tempAverage > HIGH_LIMIT_GAME) {
		videoPlayer.visible = true;
		videoPlayer2.visible = false;
		ventOverlay.getChildAt(0).rotation = 180;
		ventOverlay.getChildAt(0).x = ventOverlay.getChildAt(0).width;
		ventOverlay.getChildAt(0).y = ventOverlay.getChildAt(0).height;
		hpGame.arrowFlowL.visible = false;
		hpGame.arrowFlowR.visible = true;
	}
	else if(tempAverage < LOW_LIMIT_GAME) {
		videoPlayer2.visible = true;
		videoPlayer.visible = false;
		ventOverlay.getChildAt(0).rotation = 0;
		ventOverlay.getChildAt(0).x = 0;
		ventOverlay.getChildAt(0).y = 0;
		hpGame.arrowFlowL.visible = true;
		hpGame.arrowFlowR.visible = false;
	}
	else {
		videoPlayer2.visible = false;
		videoPlayer.visible = false;
		hpGame.arrowFlowL.visible = false;
		hpGame.arrowFlowR.visible = false;
	}

	// Normalise the read value to match one of the tempTable values
	tempLevel = int((tempAverage - INITIAL_REFERENCE_VALUE) / VALUE_STEP)*VALUE_STEP + INITIAL_REFERENCE_VALUE;
	crossSpeed = -int(tempTable[tempLevel])*2;
	// Move the temperature tag, only within the bounds of the thermometer
	if(MIN_HOUSE_THERMO < (tempTable[tempLevel] + seasonalTemperature) && (tempTable[tempLevel] + seasonalTemperature) < MAX_HOUSE_THERMO) {
		TweenLite.to(hpGame.TEMPERATURE.left_temp_mc.leftMarksBG, 0.5, {y: tempMarksBG_Y + (tempTable[tempLevel] + seasonalTemperature)*PIXELS_PER_DEGREE, ease:Linear.easeNone});
		TweenLite.to(hpGame.TEMPERATURE.left_temp_mc.leftMarks, 0.5, {y: tempMarks_Y + (tempTable[tempLevel] + seasonalTemperature)*LARGE_PIXELS_PER_DEGREE, ease:Linear.easeNone, onComplete: tweenMarks(tempLevel)});
	}
}

// Update the colour of the indoor temperature tag
private function tweenMarks(tempLevel:uint):void {
	if(hpGame.TEMPERATURE.left_temp_mc.leftMarksBG.y > (tempMarksBG_Y + PIXELS_PER_DEGREE*15)
		&& hpGame.TEMPERATURE.left_temp_mc.leftMarksBG.y < (tempMarksBG_Y + PIXELS_PER_DEGREE*21))
		tHusBGColour.brightness = 0;
	else
		tHusBGColour.brightness = -1;
/*	if(COMFY_MIN_HOUSE_THERMO <= (tempTable[tempLevel] + seasonalTemperature) && (tempTable[tempLevel] + seasonalTemperature) <= COMFY_MAX_HOUSE_THERMO)
		tHusBGColour.brightness = 0;
	else
		tHusBGColour.brightness = -1;
*/
	hpGame.TEMPERATURE.left_temp_mc.leftArrow.transform.colorTransform = tHusBGColour;

}
