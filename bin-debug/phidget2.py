#!/usr/bin/python

"""Copyright 2010 Phidgets Inc.
This work is licensed under the Creative Commons Attribution 2.5 Canada License. 
To view a copy of this license, visit http://creativecommons.org/licenses/by/2.5/ca/
"""

__author__ = 'Adam Stelmack'
__version__ = '2.1.8'
__date__ = 'May 17 2010'

#Basic imports
from ctypes import *
import sys
import random
import time
import threading

#Phidget specific imports
from Phidgets.PhidgetException import PhidgetErrorCodes, PhidgetException
from Phidgets.Events.Events import AttachEventArgs, DetachEventArgs, ErrorEventArgs, InputChangeEventArgs, OutputChangeEventArgs, SensorChangeEventArgs
from Phidgets.Devices.InterfaceKit import InterfaceKit

currentAverage = 500
currentAverageList = []
printAtLength = 5
sensorIndex = 6
sampleRate = 0.05


# Print to stdout the accumulated average sensor value obtained every sampleRate
# Creates a delay using a timer thread
def intervalPrinter():
    global currentAverage
    global currentAverageList
    global printAtLength
    t = threading.Timer(sampleRate, intervalPrinter)
    # t.daemon = True
    t.start()
    if len(currentAverageList) > printAtLength:
		currentAverage = int(sum(currentAverageList) / len(currentAverageList))
		currentAverageList = []
		print("%i" % currentAverage)
    else:
    	currentAverageList.append(interfaceKit.getSensorValue(sensorIndex))

# Creates a delay using the time.sleep method
def intervalSleepPrinter():
    global currentAverage
    global currentAverageList
    global printAtLength
    
    while True:
    	time.sleep(sampleRate)
    	if len(currentAverageList) > printAtLength:
			currentAverage = int(sum(currentAverageList) / len(currentAverageList))
			currentAverageList = []
			print("%i" % currentAverage)
    	else:
    		currentAverageList.append(interfaceKit.getSensorValue(sensorIndex))

#Create an interfacekit object
try:
    interfaceKit = InterfaceKit()
except RuntimeError as e:
    print("Runtime Exception: %s" % e.details)
    print("Exiting....")
    exit(1)

#Event Handler Callback Functions

def inferfaceKitAttached(e):
    attached = e.device
    #  print("InterfaceKit %i Attached!" % (attached.getSerialNum()))

def interfaceKitDetached(e):
    detached = e.device
    print("InterfaceKit %i Detached!" % (detached.getSerialNum()))

def interfaceKitError(e):
    try:
        source = e.device
        print("InterfaceKit %i: Phidget Error %i: %s" % (source.getSerialNum(), e.eCode, e.description))
    except PhidgetException as e:
        print("Phidget Exception %i: %s" % (e.code, e.details))


# Main Program Code
# Event listeners & exceptions
try:
    interfaceKit.setOnAttachHandler(inferfaceKitAttached)
    interfaceKit.setOnDetachHandler(interfaceKitDetached)
    interfaceKit.setOnErrorhandler(interfaceKitError)
    # interfaceKit.setOnSensorChangeHandler(interfaceKitSensorChanged)
except PhidgetException as e:
    print("Phidget Exception %i: %s" % (e.code, e.details))
    print("Exiting....")
    exit(1)

# Open the Phidget
try:
    interfaceKit.openPhidget()
except PhidgetException as e:
    print("Phidget Exception %i: %s" % (e.code, e.details))
    print("Exiting....")
    exit(1)

# Attach to the Phidget
try:
    interfaceKit.waitForAttach(10000)
except PhidgetException as e:
    print("Phidget Exception %i: %s" % (e.code, e.details))
    try:
        interfaceKit.closePhidget()
    except PhidgetException as e:
        print("Phidget Exception %i: %s" % (e.code, e.details))
        print("Exiting....")
        exit(1)
    print("Exiting....")
    exit(1)

# Set sensor trigger margin & data rate, begin the timer
try:
    interfaceKit.setSensorChangeTrigger(sensorIndex,3)
    interfaceKit.setDataRate(sensorIndex, 4)
    intervalSleepPrinter()
except PhidgetException as e:
    print("Phidget Exception %i: %s" % (e.code, e.details))

chr = sys.stdin.read(1)

try:
    interfaceKit.closePhidget()
except PhidgetException as e:
    print("Phidget Exception %i: %s" % (e.code, e.details))
    print("Exiting....")
    exit(1)

exit(0)
