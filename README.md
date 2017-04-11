# Explorer Kit Testing

The ExplorerKitTest.device.nut file includes a small test suite for testing sensors on the Explorer Kit. This code currently supports Imp001 and Imp004 kits. Included in the device.nut file is a class that contains the tests (see documentation below for details) as well as some example code including setup and runtime code.  Please adjust the example code to run the desired tests.

## Explorer Kit Test Class

### Class dependencies:

* HTS221
* LPS22HB
* LIS3DH
* WS2812

### Class Usage

#### Constructor: ExplorerKitTest(*enableAccelInt, enablePressInt*)

The constructor takes two arguments to instantiate the class: the booleans *enableAccelInt* and *enablePressInt*, these flags will be used when testing interrupts.

```
// Interrupt settings
local ENABLE_ACCEL_INT = false;
local ENABLE_PRESS_INT = true;

// Initialize test class
exKit <- ExplorerKitTest(ENABLE_ACCEL_INT, ENABLE_PRESS_INT);
```

### Class Methods

#### scanI2C()

Scans the onboard sensor i2c bus and logs addresses for the sensors it finds.

```
exKit.scanI2C();
```

#### testSleep()

Tests the power consumption during sleep.  Boots at full power for 10s, then goes into a deep sleep for 20s.

```
exKit.testSleep();
```

#### testGrove(*timer[, repeatI2C]*);

Test that grove pins are working.  This test steps through each signal pin, toggling each high one at a time. The *timer* paramter is the time in seconds each pin should be held high.  The *repeatI2C* parameter is a boolean whether to toggle the I2C pins 2x (one for each grove header), the default is false.  The i2c pins are toggled first and then the analog/digital pins are toggled (left to right on the board).

```
// Grove Settings
local GROVE_TIMER = 10; // Time in sec to hold pin high
local REPEAT_I2C = true; // repeat i2c pins

exKit.testGrove(GROVE_TIMER, REPEAT_I2C);
```

#### testTempHumid()

Configures the sensor in one shot mode, takes a reading and logs the result.

```
exKit.testTempHumid();
```

#### testAccel()

Configures the sensor, gets a reading and logs the result.

```
exKit.testAccel();
```

#### testPressure()

Configures the sensor in one shot mode, takes a reading and logs the result.

```
exKit.testPressure();
```

#### testLED()

Uses WS2812 library methods to turn the LED on for 20 sec and off for 10 sec, then toggles the LED on for 10 sec and uses the power gate to turn the LED off.

```
exKit.testLED();
```

### testInterrupts(*[testIntWakeUp]*)

Enables the interrupts based on the flags passed into the constructor. When an interrupt is detected it will be logged. Currently on the pressure and accelerometer interrupts are tested. If the boolean *testIntWakeUp* parameter is `true` the device is put to sleep and wakes when an interrupt is detected. The default value for *testIntWakeUp* is false.

```
local TEST_WAKE_INT = true;

exKit.testInterrupts(TEST_WAKE_INT);
```