// Temp/Humid Sensor Lib
#require "HTS221.class.nut:1.0.1"
// Air Pressure Sensor Lib
#require "LPS22HB.class.nut:1.0.0"
// Accelerometer Sensor Lib
#require "LIS3DH.class.nut:1.3.0"
// LED Lib
#require "WS2812.class.nut:3.0.0"

if (imp.environment() == ENVIRONMENT_CARD) {
    ExplorerKit_001 <- {
        "LED_SPI" : hardware.spi257,
        "SENSOR_AND_GROVE_I2C" : hardware.i2c89,
        "TEMP_HUMID_I2C_ADDR" : 0xBE,
        "ACCEL_I2C_ADDR" : 0x32,
        "PRESSURE_I2C_ADDR" : 0xB8,
        "POWER_GATE_AND_WAKE_PIN" : hardware.pin1,
        "AD_GROVE1_DATA1" : hardware.pin2,
        "AD_GROVE2_DATA1" : hardware.pin5
    }
} else {
    ExplorerKit_004m <- {
        "LED_SPI" : hardware.spiAHSR,
        "SENSOR_I2C" : hardware.i2cNM,
        "GROVE_I2C" : hardware.i2cQP,
        "TEMP_HUMID_I2C_ADDR" : 0xBE,
        "ACCEL_I2C_ADDR" : 0x32,
        "PRESSURE_I2C_ADDR" : 0xB8,
        "POWER_GATE" : hardware.pinH,
        "WAKE_PIN" : hardware.pinW,
        "ACCEL_INT_PIN" : hardware.pinR,
        "PRESSURE_INT_PIN" : hardware.pinS,
        "AD_GROVE1_DATA1" : hardware.pinC,
        "AD_GROVE1_DATA2" : hardware.pinB,
        "AD_GROVE2_DATA1" : hardware.pinD,
        "AD_GROVE2_DATA2" : hardware.pinK
    }
}


class ExplorerKitTest {

    _i2c = null;
    _spi = null;
    _powerGate = null;
    _wake = null;
    _pressInt = null;
    _accelInt = null;

    _004 = false;
    _enableAccelInt = null;
    _enablePressInt = null;

    tempHumid = null;
    press = null;
    accel = null;
    led = null;

    constructor(ENABLE_ACCEL_INT, ENABLE_PRESS_INT) {

        imp.enableblinkup(true);
        _enableAccelInt = ENABLE_ACCEL_INT;
        _enablePressInt = ENABLE_PRESS_INT;
        local tempHumidAddr, pressAddr, accelAddr;

        if (imp.environment() == ENVIRONMENT_CARD) {
            // IMP 001
            _i2c = ExplorerKit_001.SENSOR_AND_GROVE_I2C;
            _spi = ExplorerKit_001.LED_SPI;
            _powerGate = ExplorerKit_001.POWER_GATE_AND_WAKE_PIN;
            _wake = ExplorerKit_001.POWER_GATE_AND_WAKE_PIN;
            tempHumidAddr = ExplorerKit_001.TEMP_HUMID_I2C_ADDR
            pressAddr = ExplorerKit_001.TEMP_HUMID_I2C_ADDR
            accelAddr = ExplorerKit_001.TEMP_HUMID_I2C_ADDR
        } else {
            // IMP 004m
            _004 = true;
            _i2c = ExplorerKit_004m.SENSOR_I2C;
            _spi = ExplorerKit_004m.LED_SPI;
            _powerGate = ExplorerKit_004m.POWER_GATE;
            _wake = ExplorerKit_004m.WAKE_PIN;
            _pressInt = ExplorerKit_004m.PRESSURE_INT_PIN;
            _accelInt = ExplorerKit_004m.ACCEL_INT_PIN;
            tempHumidAddr = ExplorerKit_004m.TEMP_HUMID_I2C_ADDR
            pressAddr = ExplorerKit_004m.TEMP_HUMID_I2C_ADDR
            accelAddr = ExplorerKit_004m.TEMP_HUMID_I2C_ADDR
        }

        _i2c.configure(CLOCK_SPEED_400_KHZ);

        // initialize sensors
        led = WS2812(_spi, 1);
        tempHumid = HTS221(_i2c, tempHumidAddr);
        press = LPS22HB(_i2c, pressAddr);
        accel = LIS3DH(_i2c, accelAddr);

        checkWakeReason();
    }

    function checkWakeReason() {
        local wakeReason = hardware.wakereason();
        switch (wakeReason) {
            case WAKEREASON_PIN:
                // Woke on interrupt pin
                if (_enableAccelInt) _accelIntHandler();
                if (_enablePressInt) _pressIntHandler();
                server.log("Woke b/c int pin triggered")
                break;
            case WAKEREASON_TIMER:
                // Woke on timer
                server.log("Woke b/c timer expired");
                break;
            default :
                // Everything else
                server.log("Rebooting...");
        }
    }

    function scanI2C() {
        for (local i = 2 ; i < 256 ; i+=2) {
            if (_i2c.read(i, "", 1) != null) server.log(format("Device at address: 0x%02X", i));
        }
    }

    function testSleep() {
        server.log("At full power...");
        imp.sleep(10);
        server.log("Going to deep sleep for 20s...");
        accel.enable(false);
        imp.onidle(function() { imp.deepsleepfor(20); })
    }

    function testTempHumid() {
        // Take a sync reading and log it
        tempHumid.setMode(HTS221_MODE.ONE_SHOT);
        local thReading = tempHumid.read();
        if ("error" in thReading) server.error(thReading.error);
        server.log(format("Current Humidity: %0.2f %s, Current Temperature: %0.2f °C", thReading.humidity, "%", thReading.temperature));
    }

    function testAccel() {
        // Take a sync reading and log it
        accel.init();
        accel.setDataRate(10);
        accel.enable();
        local accelReading = accel.getAccel();
        server.log(format("Acceleration (G): (%0.2f, %0.2f, %0.2f)", accelReading.x, accelReading.y, accelReading.z));
    }

    function testPressure() {
        // Take a sync reading and log it
        press.softReset();
        local pressReading = press.read();
        server.log(pressReading.pressure);
        server.log(format("Current Pressure: %0.2f in Hg", (1.0 * pressReading.pressure)/33.8638866667));
    }

    function testLED() {
        _powerGate.configure(DIGITAL_OUT, 1);
        server.log("Turning LED on")
        led.fill([10, 10, 10]).draw();
        imp.wakeup(20, function() {
            server.log("Turning LED off");
            led.fill([0,0,0]).draw();
        }.bindenv(this));

        imp.wakeup(30, function() {
            server.log("Turning LED on");
            led.fill([10, 10, 10]).draw();
            imp.wakeup(10, function() {
                server.log("Turning LED off by toggling power gate");
                _powerGate.write(0);
            }.bindenv(this));
        }.bindenv(this));
    }

    // Parameters
    //  timer: time in sec to hold each pin high
    //  repeatI2C: toggle i2c pin loop 2X
    function testGrove(timer, repeatI2C = false) {
        _powerGate.configure(DIGITAL_OUT, 1);

        server.log("Power to SCL High");
        if (_004) {
            hardware.pinQ.configure(DIGITAL_OUT, 1);
        } else {
            hardware.pin8.configure(DIGITAL_OUT, 1);
        }
        imp.sleep(timer);

        server.log("Power to SDA High");
        if (_004) {
            hardware.pinQ.configure(DIGITAL_OUT, 0);
            hardware.pinP.configure(DIGITAL_OUT, 1);
        } else {
            hardware.pin8.configure(DIGITAL_OUT, 0);
            hardware.pin9.configure(DIGITAL_OUT, 1);
        }
        imp.sleep(timer);

        if (repeatI2C) {
            server.log("Power to SCL High");
            if (_004) {
                hardware.pinQ.configure(DIGITAL_OUT, 1);
            } else {
                hardware.pin8.configure(DIGITAL_OUT, 1);
            }
            imp.sleep(timer);

            server.log("Power to SDA High");
            if (_004) {
                hardware.pinQ.configure(DIGITAL_OUT, 0);
                hardware.pinP.configure(DIGITAL_OUT, 1);
            } else {
                hardware.pin8.configure(DIGITAL_OUT, 0);
                hardware.pin9.configure(DIGITAL_OUT, 1);
            }
            imp.sleep(timer);
        }

        if (_004) {
            server.log("Power to Grove 1 D1 High");
            hardware.pinP.configure(DIGITAL_OUT, 0);
            ExplorerKit_004m.AD_GROVE1_DATA1.configure(DIGITAL_OUT, 1);
            imp.sleep(timer);
            server.log("Power to Grove 1 D2 High");
            ExplorerKit_004m.AD_GROVE1_DATA1.configure(DIGITAL_OUT, 0);
            ExplorerKit_004m.AD_GROVE1_DATA2.configure(DIGITAL_OUT, 1);
        } else {
            server.log("Power to Grove 1 Analog/Digital High");
            hardware.pin9.configure(DIGITAL_OUT, 0);
            ExplorerKit_001.AD_GROVE1_DATA1.configure(DIGITAL_OUT, 1);
        }
        imp.sleep(timer);

        if (_004) {
            server.log("Power to Grove 2 D1 High");
            ExplorerKit_004m.AD_GROVE1_DATA2.configure(DIGITAL_OUT, 0);
            ExplorerKit_004m.AD_GROVE2_DATA1.configure(DIGITAL_OUT, 1);
            imp.sleep(timer);
            server.log("Power to Grove 2 D2 High");
            ExplorerKit_004m.AD_GROVE2_DATA1.configure(DIGITAL_OUT, 0);
            ExplorerKit_004m.AD_GROVE2_DATA2.configure(DIGITAL_OUT, 1);
        } else {
            server.log("Power to Grove 2 Analog/Digital High");
            ExplorerKit_001.AD_GROVE1_DATA1.configure(DIGITAL_OUT, 0);
            ExplorerKit_001.AD_GROVE2_DATA1.configure(DIGITAL_OUT, 1);
        }
        imp.sleep(timer);

        // reset pins
        if (_004) {
            ExplorerKit_004m.AD_GROVE2_DATA2.configure(DIGITAL_OUT, 0);
        } else {
            ExplorerKit_001.AD_GROVE2_DATA1.configure(DIGITAL_OUT, 0);
        }
    }

    function testInterrupts(testWake = false) {
        clearInterrupts();

        // Configure interrupt pins
        _wake.configure(DIGITAL_IN_WAKEUP, function() {
            // When awake only trigger on pin high
            if (!testWake && _wake.read() == 0) return;

            // Determine interrupt
            if (_enableAccelInt) _accelIntHandler();
            if (_enablePressInt) _pressIntHandler();

        }.bindenv(this));

        if (_enableAccelInt) _enableAccelInterrupt();
        if (_enablePressInt) _enablePressInterrupt();

        if (testWake) {
            _sleep();
        }
    }


    function logIntPinState() {
        server.log("Wake pin: " + _wake.read());
        if (_004) {
            server.log("Accel int pin: " + _accelInt.read());
            server.log("Press int pin: " + _pressInt.read());
        }
    }

    // Private functions/Interrupt helpers
    // -------------------------------------------------------

    function _sleep() {
        if (_wake.read() == 1) {
            logIntPinState();
            imp.wakeup(1, sleep.bindenv(this));
        } else {
            imp.onidle(function() { server.sleepfor(300); });
        }
    }

    function clearInterrupts() {
        accel.configureFreeFallInterrupt(false);
        press.configureThresholdInterrupt(false);
        accel.getInterruptTable();
        press.getInterruptSrc();
        logIntPinState();
    }

    function _enableAccelInterrupt() {
        accel.setDataRate(100);
        accel.enable();
        accel.configureInterruptLatching(true);
        accel.getInterruptTable();
        accel.configureFreeFallInterrupt(true);
        server.log("Free fall interrupt configured...");
    }

    function _accelIntHandler() {
        local intTable = accel.getInterruptTable();
        if (intTable.int1) server.log("Free fall detected: " + intTable.int1);
    }

    function _enablePressInterrupt() {
        press.setMode(LPS22HB_MODE.CONTINUOUS, 25);
        local intTable = press.getInterruptSrc();
        press.configureThresholdInterrupt(true, 1000, LPS22HB.INT_LATCH | LPS22HB.INT_LOW_PRESSURE | LPS22HB.INT_HIGH_PRESSURE);
        server.log("Pressure interrupt configured...");
    }

    function _pressIntHandler() {
        local intTable = press.getInterruptSrc();
        if (intTable.int_active) {
            server.log("Pressure int triggered: " + intTable.int_active);
            if (intTable.high_pressure) server.log("High pressure int: " + intTable.high_pressure);
            if (intTable.low_pressure) server.log("Low pressure int: " + intTable.low_pressure);
        }
    }

}


// SETUP
// ------------------------------------------

// Interrupt settings
local TEST_WAKE_INT = false;
local ENABLE_ACCEL_INT = false;
local ENABLE_PRESS_INT = false;

// Grove Settings
local GROVE_TIMER = 10; // Time in sec to hold pin high
local REPEAT_I2C = true; // repeat i2c pins

// Initialize test class
exKit <- ExplorerKitTest(ENABLE_ACCEL_INT, ENABLE_PRESS_INT);

// RUN TESTS
// ------------------------------------------

// // Scan for the sensor addresses
// exKit.scanI2C();

// // Test power consumption during sleep
// exKit.testSleep();

// // Test that grove pins are working
// exKit.testGrove(GROVE_TIMER, REPEAT_I2C);

// // Test that all sensors can take a reading,
// // and that LED truns on and off (via library calls or toggling power gate)
exKit.testTempHumid();
exKit.testAccel();
exKit.testPressure();
exKit.testLED();

// // Test Interrupt
// exKit.testInterrupts(TEST_WAKE_INT);
