#include <ArduinoBLE.h>
#include <LibPrintf.h>
#include "bluetooth.h"

const char *serviceUUID = "19b10000-e8f2-537e-4f6c-d104768a1214";
const char *characteristicUUID = "ca164c88-9eee-47a0-8c1f-f875f38d0351";

BLEService vitalService(serviceUUID);

BLECharacteristic customCharacteristic(characteristicUUID, BLERead | BLEWrite, 256);

BLEService *servs = &vitalService;
BLECharacteristic *chars[1] = {&customCharacteristic};

const char *deviceName = "Heart Rate Monitor";

BLUETOOTH ble(vitalService, chars, deviceName);

void setup()
{
  Serial.begin(115200);
  BLE.begin();
  ble.establishServiceWithCharacteristics(vitalService, chars, 1, deviceName);
}

// WORK BELOW!!!

// Each vital value - uint16_t [2 bytes]
// Each length of payload value - uint32_t [4 bytes]
// Each command byte - std::uint8_t [1 byte]

// A0 - Sensor Readings
// A1 - Time Frame width setting

/*

The sizing of FULL_PAYLOAD is dependant on the MTU of device which is 509 bytes. We won't go any more than that since it requires
multiple sends per package, delaying vital's reading

*/ 

std::uint8_t FULL_PAYLOAD[509];

std::uint8_t vitalData[500];
uint16_t numberOfValuesToSend = 30;
uint16_t currentIndex = 0;

const std::uint8_t vitalCommandByte = 0x06;

uint16_t determineValueFromPotentiometer(std::uint8_t analogPin, uint16_t interpInitial, uint16_t interpFinal);

bool isConnectedToCentral = false;
bool isSendingData = true;

std::uint8_t incomingData[20]{};

std::uint8_t stopSendingDataByte = 0x08;
std::uint8_t startSendingDataByte = 0x10;

unsigned long previousTime = millis();
unsigned long currentTime = millis();

uint16_t timeDelta = 0;

void loop()
{

  BLE.poll();

  printf("Sensor Reading %.0f | Time Frame Knob: %.0f", analogRead(A0), analogRead(A1));

  BLEDevice central = BLE.central();

  isConnectedToCentral = central ? true : false;

  if (isConnectedToCentral && isSendingData)
  {
    if (currentIndex < numberOfValuesToSend)
    {
      const uint16_t vitalReading = determineValueFromPotentiometer(A0, 0, 1023); // Using A0 for the readings

      currentTime = millis();

      memcpy(&FULL_PAYLOAD[5 + (currentIndex++ * 2)], &vitalReading, 2);
    }
    else
    {
      // SEND DATA. FILL

      timeDelta = currentTime - previousTime;

      const uint16_t payloadSize = 2 + 2 + 1 + (numberOfValuesToSend * 2); // 2 for size (THIS), 2 for time delta, 1 for command, n for numberOfValuesToSend (Actual data)

      memcpy(&FULL_PAYLOAD[0], &payloadSize, 2);
      memcpy(&FULL_PAYLOAD[2], &vitalCommandByte, 1);

      memcpy(&FULL_PAYLOAD[3], &timeDelta, 2);

      ble.writeValueFromCharacteristicIndex(0, payloadSize, FULL_PAYLOAD);

      currentIndex = 0;
      //numberOfValuesToSend = (uint16_t)determineValueFromPotentiometer(A1, 0, 245);

      previousTime = millis();
    }
  }

  /*

  I define that if MATLAB tells us to start sending data:
  Reset the currentindex value and set isSendingData to true

  and vise versa for stopping

  */

  if (ble.readFromCharacteristicInLoop(&customCharacteristic, incomingData, 9))
  {

    Serial.println(incomingData[0]);

    if (incomingData[0] == stopSendingDataByte)
    {
      isSendingData = false;
      currentIndex = 0;
    }
    else if (incomingData[0] == startSendingDataByte)
    {
      isSendingData = true;
      previousTime = millis();
      currentIndex = 0;
      //numberOfValuesToSend = (uint16_t)determineValueFromPotentiometer(A1, 0, 245);
    }
    ble.sendAckByte(1, 0x06);
  }
}

uint16_t determineValueFromPotentiometer(std::uint8_t analogPin, uint16_t interpInitial, uint16_t interpFinal)
{
  float fraction = (float)analogRead(analogPin) / 1023.0f;
  uint16_t difference = interpFinal - interpInitial;

  return (fraction * (difference)) + interpInitial;

  /*
  I've created this function to easily determine what value I need from the potentiometer
  without doing all the math each time, making life easier
  */
}
