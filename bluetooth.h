#pragma once

#include <Arduino.h>
#include <ArduinoBLE.h>
#include <cstdint>
#include <cstring>

class BLUETOOTH
{
private:
    bool initialized = false;

    const char *devName = nullptr;
    BLEService *service = nullptr;
    BLECharacteristic **characteristics = nullptr;

public:
    BLUETOOTH() = default;

    BLUETOOTH(BLEService &BLE_SERVICE)
        : service(&BLE_SERVICE) {}

    BLUETOOTH(BLEService &BLE_SERVICE, BLECharacteristic **BLE_CHARACTERISTIC)
        : service(&BLE_SERVICE), characteristics(BLE_CHARACTERISTIC) {}

    BLUETOOTH(BLEService &BLE_SERVICE, BLECharacteristic **BLE_CHARACTERISTIC, const char *NAME)
        : devName(NAME), service(&BLE_SERVICE), characteristics(BLE_CHARACTERISTIC) {}

    void establishServiceWithCharacteristics(BLEService &BLE_SERVICE, BLECharacteristic **BLE_CHARACTERISTIC, std::uint8_t numOfCharacteristics, const char *NAME)
    {
        this->devName = NAME;
        this->service = &BLE_SERVICE;

        for (std::uint8_t i = 0; i < numOfCharacteristics; i++)
        {
            this->characteristics[i] = BLE_CHARACTERISTIC[i];
            this->service->addCharacteristic(*(this->characteristics[i]));
        }

        BLE.setDeviceName(NAME);
        BLE.setLocalName(NAME);

        BLEAdvertisingData scanData;
        scanData.setLocalName(NAME);

        BLE.setScanResponseData(scanData);

        BLE.addService(*(this->service));
        BLE.setAdvertisedService(*(this->service));

        std::uint8_t zeroVal = 0;
        for (std::uint8_t i = 0; i < numOfCharacteristics; i++)
        {
            this->characteristics[i]->writeValue(&zeroVal, sizeof(zeroVal));
        }

        BLE.advertise();
        this->initialized = true;

        Serial.println("Established Service with Characteristics");
    }

    bool isInitialized() const
    {
        return this->initialized;
    }

    bool readFromCharacteristicInLoop(BLECharacteristic *characteristic, std::uint8_t *outBuffer, const std::uint8_t numOfBytes)
    {

        BLEDevice central = BLE.central();

        if (central && central.connected())
        {
            if (characteristic->written())
            {
                characteristic->readValue(outBuffer, numOfBytes);
                return true;
            }
        }

        return false;
    }

    void writeValueFromCharacteristicIndex(std::uint8_t index, const uint16_t numOfBytes, const std::uint8_t *values)
    {
        if (this->characteristics != nullptr)
        {
            this->characteristics[index]->writeValue(values, numOfBytes);
        }
    }

    void writeFloatBufferFromCharacteristicIndex(int index, const uint16_t numOfValues, const float *values)
    {
        if (this->characteristics != nullptr && values != nullptr)
        {
            uint16_t byteLength = numOfValues * sizeof(float);
            this->characteristics[index]->writeValue(reinterpret_cast<const std::uint8_t *>(values), byteLength);
        }
    }

    void sendRXData(int index, const uint16_t numOfBytes, const std::uint8_t *values)
    {
        this->writeValueFromCharacteristicIndex(index, numOfBytes, values);
    }

    void sendAckByte(int index, byte ackByte)
    {
        if (this->characteristics != nullptr)
        {
            this->characteristics[index]->writeValue(ackByte);
        }
    }
};
