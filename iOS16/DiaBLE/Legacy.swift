import Foundation
import CoreBluetooth
import SwiftUI


// https://github.com/birdfly/DiaBLE/commit/d604bf7
// "Strip off the management of the Watlaa, preferred watches and bridge transmitters"


class Droplet: Transmitter {
    // override class var type: DeviceType { DeviceType.transmitter(.droplet) }
    override class var name: String { "Droplet" }
    override class var dataServiceUUID: String { "C97433F0-BE8F-4DC8-B6F0-5343E6100EB4" }
    override class var dataReadCharacteristicUUID: String { "C97433F1-BE8F-4DC8-B6F0-5343E6100EB4" }
    override class var dataWriteCharacteristicUUID: String { "C97433F2-BE8F-4DC8-B6F0-5343E6100EB4" }

    enum LibreType: String, CustomStringConvertible {
        case L1   = "10"
        case L2   = "20"
        case US14 = "30"
        case Lpro = "40"

        var description: String {
            switch self {
            case .L1:   return "Libre 1"
            case .L2:   return "Libre 2"
            case .US14: return "Libre US 14d"
            case .Lpro: return "Libre Pro"
            }
        }
    }

    override func read(_ data: Data, for uuid: String) {
        if sensor == nil {
            sensor = Sensor(transmitter: self)
            main.app.sensor = sensor
        }
        if data.count == 8 {
            sensor!.uid = Data(data)
            main.log("\(name): sensor serial number: \(sensor!.serial))")
        } else {
            main.log("\(name) response: 0x\(data[0...0].hex)")
            main.log("\(name) response data length: \(Int(data[1]))")
        }
        // TODO:  9999 = error
    }
}


class Limitter: Droplet {
    // override class var type: DeviceType { DeviceType.transmitter(.limitter) }
    override class var name: String { "Limitter" }

    override func readCommand(interval: Int = 5) -> Data {
        return Data([UInt8(32 + interval)]) // 0x2X
    }

    override func read(_ data: Data, for uuid: String) {

        // https://github.com/SpikeApp/Spike/blob/master/src/services/bluetooth/CGMBluetoothService.as

        if sensor == nil {
            sensor = Sensor(transmitter: self)
            main.app.sensor = sensor
        }

        let fields = data.string.split(separator: " ")
        guard fields.count == 4 else { return }

        battery = Int(fields[2])!
        main.log("\(name): battery: \(battery)")

        let firstField = fields[0]
        guard !firstField.hasPrefix("000") else {
            main.log("\(name): no sensor data")
            main.status("\(name): no data from sensor")
            if firstField.hasSuffix("999") {
                let err = fields[1]
                main.log("\(name): error \(err)\n(0001 = low battery, 0002 = badly positioned)")
            }
            return
        }

        let rawValue = Int(firstField.dropLast(2))!
        main.log("\(name): glucose raw value: \(rawValue)")
        main.status("\(name) raw glucose: \(rawValue)")
        main.app.currentGlucose = rawValue / 10

        let sensorType = LibreType(rawValue: String(firstField.suffix(2)))!.description
        main.log("\(name): sensor type = \(sensorType)")

        sensor!.age = Int(fields[3])! * 10
        if Double(sensor!.age)/60/24 < 14.5 {
            sensor!.state = .active
        } else {
            sensor!.state = .expired
        }
        main.log("\(name): sensor age: \(Int(sensor!.age)) minutes (\(String(format: "%.1f", Double(sensor!.age)/60/24)) days)")
        main.status("\(sensorType)  +  \(name)")
    }
}

// Legacy code from bluetoothDelegate didDiscoverCharacteristicsFor

// if app.transmitter.type == .transmitter(.droplet) && serviceUUID == Droplet.dataServiceUUID {

// https://github.com/MarekM60/eDroplet/blob/master/eDroplet/eDroplet/ViewModels/CgmPageViewModel.cs
// Droplet - New Protocol.pdf: https://www.facebook.com/download/preview/961042740919138

// app.transmitter.write([0x31, 0x32, 0x33]); log("Droplet: writing old ping command")
// app.transmitter.write([0x34, 0x35, 0x36]); log("Droplet: writing old read command")
// app.transmitter.write([0x50, 0x00, 0x00]); log("Droplet: writing ping command P00")
// app.transmitter.write([0x54, 0x00, 0x01]); log("Droplet: writing timer command T01")
// T05 = 5 minutes, T00 = quiet mode
// app.transmitter.write([0x53, 0x00, 0x00]); log("Droplet: writing sensor identification command S00")
// app.transmitter.write([0x43, 0x00, 0x01]); log("Droplet: writing FRAM reading command C01")
// app.transmitter.write([0x43, 0x00, 0x02]); log("Droplet: writing FRAM reading command C02")
// app.transmitter.write([0x42, 0x00, 0x01]); log("Droplet: writing RAM reading command B01")
// app.transmitter.write([0x42, 0x00, 0x02]); log("Droplet: writing RAM reading command B02")
// "A0xyz...z” sensor activation where: x=1 for Libre 1, 2 for Libre 2 and US 14-day, 3 for Libre Pro/H; y = length of activation bytes, z...z = activation bytes
// }

// if app.transmitter.type == .transmitter(.limitter) && serviceUUID == Limitter.dataServiceUUID {
//    let readCommand = app.transmitter.readCommand(interval: settings.readingInterval)
//    app.transmitter.write(readCommand)
//    log("Droplet (LimiTTer): writing start reading command 0x\(Data(readCommand).hex)")
//    app.transmitter.peripheral?.readValue(for: app.transmitter.readCharacteristic!)
//    log("Droplet (LimiTTer): reading data")
// }


// https://github.com/bubbledevteam/bubble-client-swift/


class Bubble: Transmitter {
    override class var type: DeviceType { DeviceType.transmitter(.bubble) }
    override class var name: String { "Bubble" }

    enum UUID: String, CustomStringConvertible, CaseIterable {
        case data      = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
        case dataWrite = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
        case dataRead  = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

        var description: String {
            switch self {
            case .data:      return "data"
            case .dataWrite: return "data write"
            case .dataRead:  return "data read"
            }
        }
    }

    override class var knownUUIDs: [String] { UUID.allCases.map(\.rawValue) }

    override class var dataServiceUUID: String             { UUID.data.rawValue }
    override class var dataWriteCharacteristicUUID: String { UUID.dataWrite.rawValue }
    override class var dataReadCharacteristicUUID: String  { UUID.dataRead.rawValue }

    enum ResponseType: UInt8, CustomStringConvertible {
        case dataInfo            = 0x80
        case dataPacket          = 0x82
        case decryptedDataPacket = 0x88
        case securityChallenge   = 0x8A
        case noSensor            = 0xBF
        case serialNumber        = 0xC0
        case patchInfo           = 0xC1

        var description: String {
            switch self {
            case .dataInfo:            return "data info"
            case .dataPacket:          return "data packet"
            case .decryptedDataPacket: return "decrypted data packet"
            case .securityChallenge:   return "security challenge"
            case .noSensor:            return "no sensor"
            case .serialNumber:        return "serial number"
            case .patchInfo:           return "patch info"
            }
        }
    }


    override func readCommand(interval: Int = 5) -> Data {
        return Data([0x00, 0x00, UInt8(interval)])
    }


    override func parseManufacturerData(_ data: Data) {
        let transmitterData = Data(data[8...11])
        firmware = "\(Int(transmitterData[0])).\(Int(transmitterData[1]))"
        hardware = "\(Int(transmitterData[2])).\(Int(transmitterData[3]))"
        macAddress = Data(data[2...7].reversed())
        var msg = "\(Self.name): advertised manufacturer data: firmware: \(firmware), hardware: \(hardware), MAC address: \(macAddress.hexAddress)"
        if data.count > 12 {
            battery = Int(data[12])
            msg += ", battery: \(battery)"
        }
        log(msg)
    }


    override func read(_ data: Data, for uuid: String) {

        // https://github.com/NightscoutFoundation/xDrip/blob/master/app/src/main/java/com/eveningoutpost/dexdrip/Models/Bubble.java

        let response = ResponseType(rawValue: data[0])
        log("\(name) response: \(response?.description ?? "unknown") (0x\(data[0...0].hex))")

        if response == .noSensor {
            main.status("\(name): no sensor")

        } else if response == .dataInfo {
            battery = Int(data[4])
            firmware = "\(data[2]).\(data[3])"
            hardware = "\(data[data.count - 2]).\(data[data.count - 1])"
            log("\(name): battery: \(battery), firmware: \(firmware), hardware: \(hardware)")
            let libreType = main.settings.patchInfo.count > 0 ? SensorType(patchInfo: main.settings.patchInfo) : .unknown
            if Double(firmware)! >= 2.6 && (libreType == .libre2 || libreType == .libreUS14day) {
                write(Data([0x08, 0x01, 0x00, 0x00, 0x00, 0x2B]))
            } else {
                write(Data([0x02, 0x01, 0x00, 0x00, 0x00, 0x2B]))
            }

        } else {
            // TODO: instantiate specifically a Libre2() (when detecting A4 in the uid, i. e.)
            if sensor == nil {
                sensor = Sensor(transmitter: self)
                main.app.sensor = sensor
            }
            if response == .serialNumber {
                sensorUid = Data(data[2...9])
                sensor!.uid = sensorUid
                main.settings.patchUid = sensorUid
                log("\(name): patch uid: \(sensor!.uid.hex)")

            } else if response == .patchInfo {
                sensor!.patchInfo = Data(Double(firmware)! < 1.35 ? data[3...8] : data[5...10])
                main.settings.patchInfo = sensor!.patchInfo
                main.settings.activeSensorSerial = sensor!.serial
                log("\(name): patch info: \(sensor!.patchInfo.hex), sensor type: \(sensor!.type.rawValue), serial number: \(sensor!.serial)")

            } else if response == .securityChallenge {
                if buffer.count == 0 {
                    buffer.append(data.suffix(from: 5))
                } else if buffer.count == 15 {
                    buffer.append(data.suffix(from: 4))
                }
                log("\(name): partial buffer size: \(buffer.count)")
                if buffer.count == 28 {
                    log("\(name): gen2 security challenge: \(buffer.prefix(25).hex)")
                    buffer = Data()
                }

            } else if response == .dataPacket || response == .decryptedDataPacket {
                if buffer.count == 0 {
                    main.app.lastReadingDate = main.app.lastConnectionDate
                    sensor!.lastReadingDate = main.app.lastConnectionDate
                }
                buffer.append(data.suffix(from: 4))
                log("\(name): partial buffer size: \(buffer.count)")
                if buffer.count >= 344 {
                    let fram = buffer[..<344]
                    // let footer = buffer.suffix(8)    // when firmware < 2.0
                    sensor!.fram = Data(fram)
                    main.status("\(sensor!.type)  +  \(name)")
                }
            }
        }
    }
}


class MiaoMiao: Transmitter {
    // override class var type: DeviceType { DeviceType.transmitter(.miaomiao) }
    override class var name: String { "MiaoMiao" }

    enum UUID: String, CustomStringConvertible, CaseIterable {
        case data      = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
        case dataWrite = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
        case dataRead  = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

        var description: String {
            switch self {
            case .data:      return "data"
            case .dataWrite: return "data write"
            case .dataRead:  return "data read"
            }
        }
    }

    override class var knownUUIDs: [String] { UUID.allCases.map(\.rawValue) }

    override class var dataServiceUUID: String             { UUID.data.rawValue }
    override class var dataWriteCharacteristicUUID: String { UUID.dataWrite.rawValue }
    override class var dataReadCharacteristicUUID: String  { UUID.dataRead.rawValue }

    enum ResponseType: UInt8, CustomStringConvertible {
        case dataPacket = 0x28
        case newSensor  = 0x32
        case noSensor   = 0x34
        case frequencyChange = 0xD1

        var description: String {
            switch self {
            case .dataPacket:      return "data packet"
            case .newSensor:       return "new sensor"
            case .noSensor:        return "no sensor"
            case .frequencyChange: return "frequency change"
            }
        }
    }

    override init(peripheral: CBPeripheral?, main: MainDelegate) {
        super.init(peripheral: peripheral!, main: main)
        if let peripheral, peripheral.name!.contains("miaomiao2") {
            name += " 2"
        }
    }

    override func readCommand(interval: Int = 5) -> Data {
        var command = [UInt8(0xF0)]
        if [1, 3].contains(interval) {
            command.insert(contentsOf: [0xD1, UInt8(interval)], at: 0)
        }
        return Data(command)
    }

    override func parseManufacturerData(_ data: Data) {
        if data.count >= 8 {
            macAddress = data.suffix(6)
            log("\(Self.name): MAC address: \(macAddress.hexAddress)")
        }
    }

    override func read(_ data: Data, for uuid: String) {

        // https://github.com/NightscoutFoundation/xDrip/blob/master/app/src/main/java/com/eveningoutpost/dexdrip/Models/Tomato.java
        // https://github.com/UPetersen/LibreMonitor/blob/Swift4/LibreMonitor/Bluetooth/MiaoMiaoManager.swift
        // https://github.com/gshaviv/ninety-two/blob/master/WoofWoof/MiaoMiao.swift

        let response = ResponseType(rawValue: data[0])
        if buffer.count == 0 {
            log("\(name) response: \(response?.description ?? "unknown") (0x\(data[0...0].hex))")
        }
        if data.count == 1 {
            if response == .noSensor {
                main.status("\(name): no sensor")
            }
            // TODO: prompt the user and allow writing the command 0xD301 to change sensor
            if response == .newSensor {
                main.status("\(name): detected a new sensor")
            }
        } else if data.count == 2 {
            if response == .frequencyChange {
                if data[1] == 0x01 {
                    log("\(name): success changing frequency")
                } else {
                    log("\(name): failed to change frequency")
                }
            }
        } else {
            // TODO: instantiate specifically a Libre2() (when detecting A4 in the uid, i. e.)
            if sensor == nil {
                sensor = Sensor(transmitter: self)
                main.app.sensor = sensor
            }
            if buffer.count == 0 {
                main.app.lastReadingDate = main.app.lastConnectionDate
                sensor!.lastReadingDate = main.app.lastConnectionDate
            }
            buffer.append(data)
            log("\(name): partial buffer size: \(buffer.count)")

            var framBlocks = 43

            if buffer.count >= 363 {  // 18 + framBlocks * 8 + 1
                log("\(name): data size: \(Int(buffer[1]) << 8 + Int(buffer[2]))")

                battery = Int(buffer[13])
                firmware = buffer[14...15].hex
                hardware = buffer[16...17].hex
                log("\(name): battery: \(battery), firmware: \(firmware), hardware: \(hardware)")

                sensor!.age = Int(buffer[3]) << 8 + Int(buffer[4])
                sensorUid = Data(buffer[5...12])
                sensor!.uid = sensorUid
                main.settings.patchUid = sensorUid
                log("\(name): sensor age: \(sensor!.age) minutes (\(String(format: "%.1f", Double(sensor!.age)/60/24)) days), patch uid: \(sensor!.uid.hex)")


                if buffer.count >= 369 {  // 18 + 43 * 8 + 1 + 6
                    // TODO: verify that buffer[362] is the end marker 0x29
                    sensor!.patchInfo = Data(buffer[363...368])
                    main.settings.patchInfo = sensor!.patchInfo
                    main.settings.activeSensorSerial = sensor!.serial
                    log("\(name): patch info: \(sensor!.patchInfo.hex), sensor type: \(sensor!.type.rawValue), serial number: \(sensor!.serial)")

                    if sensor != nil && sensor!.type == .libreProH {
                        let libreProSensor = LibrePro(transmitter: self)
                        // FIXME: buffer[3...4] doesn't match the real sensor age in body[2...3]
                        libreProSensor.age = sensor!.age
                        libreProSensor.uid = sensor!.uid
                        libreProSensor.patchInfo = sensor!.patchInfo
                        libreProSensor.lastReadingDate = sensor!.lastReadingDate
                        sensor = libreProSensor
                        main.app.sensor = sensor

                        // TODO: manage the 21 partial historic blocks (28 measurements)
                        framBlocks = 43 // 22

                    }
                } else {
                    // https://github.com/dabear/LibreOOPAlgorithm/blob/master/app/src/main/java/com/hg4/oopalgorithm/oopalgorithm/AlgorithmRunner.java
                    sensor!.patchInfo = Data([0xDF, 0x00, 0x00, 0x01, 0x01, 0x02])
                }
                sensor!.fram = Data(buffer[18 ..< 18 + framBlocks * 8])

                main.status("\(sensor!.type)  +  \(name)")
            }
        }
    }
}

// Legacy code from bluetoothDelegate didDiscoverCharacteristicsFor:

// if app.device.type == .transmitter(.miaomiao) && serviceUUID == MiaoMiao.dataServiceUUID {
//     let readCommand = app.device.readCommand(interval: settings.readingInterval)
//     app.device.write(readCommand)
//     log("\(app.device.name): writing start reading command 0x\(Data(readCommand).hex)")
//     // app.device.write([0xD3, 0x01]); log("MiaoMiao: writing start new sensor command D301")
// }

// Legacy code from bluetoothDelegate didUpdateValueFor:

// var headerLength = 0
// if app.device.type == .transmitter(.miaomiao) && characteristic.uuid.uuidString == MiaoMiao.dataReadCharacteristicUUID {
//     headerLength = 18 + 1
// }
// if let sensor = app.transmitter.sensor, sensor.fram.count > 0, app.transmitter.buffer.count >= (sensor.fram.count + headerLength) {
//     main.parseSensorData(sensor)
//     app.transmitter.buffer = Data()
// }


// https://github.com/NightscoutFoundation/xDrip/blob/master/app/src/main/java/com/eveningoutpost/dexdrip/UtilityModels/Blukon.java
// https://github.com/JohanDegraeve/xdripswift/tree/master/xdrip/BluetoothTransmitter/CGM/Libre/Blucon


class BluCon: Transmitter {
    override class var type: DeviceType { DeviceType.transmitter(.blu) }
    override class var name: String { "BluCon" }

    /// 6-digit pairing pass code, i.e. 415420
    var passCode: Data = Data()

    enum UUID: String, CustomStringConvertible, CaseIterable {
        case data      = "436A62C0-082E-4CE8-A08B-01D81F195B24"
        case dataWrite = "436AA6E9-082E-4CE8-A08B-01D81F195B24"
        case dataRead  = "436A0C82-082E-4CE8-A08B-01D81F195B24"

        var description: String {
            switch self {
            case .data:      return "data"
            case .dataWrite: return "data write"
            case .dataRead:  return "data read"
            }
        }
    }

    override class var knownUUIDs: [String] { UUID.allCases.map(\.rawValue) }

    override class var dataServiceUUID: String             { UUID.data.rawValue }
    override class var dataWriteCharacteristicUUID: String { UUID.dataWrite.rawValue }
    override class var dataReadCharacteristicUUID: String  { UUID.dataRead.rawValue }


    enum ResponseType: String, CustomStringConvertible {
        case ack            = "8b0a00"
        case patchUidInfo   = "8b0e"
        case noSensor       = "8b1a02000f"
        case readingError   = "8b1a020011"
        case timeout        = "8b1a020014"
        case sensorInfo     = "8bd9"
        case battery        = "8bda"
        case firmware       = "8bdb"
        case singleBlock    = "8bde"
        case multipleBlocks = "8bdf"
        case wakeup         = "cb010000"
        case batteryLow1    = "cb020000"
        case batteryLow2    = "cbdb0000"

        var description: String {
            switch self {
            case .ack:            return "ack"
            case .patchUidInfo:   return "patch uid/info"
            case .noSensor:       return "no sensor"
            case .readingError:   return "reading error"
            case .timeout:        return "timeout"
            case .sensorInfo:     return "sensor info"
            case .battery:        return "battery"
            case .firmware:       return "firmware"
            case .singleBlock:    return "single block"
            case .multipleBlocks: return "multiple blocks"
            case .wakeup:         return "wake up"
            case .batteryLow1:    return "battery low 1"
            case .batteryLow2:    return "battery low 2"
            }
        }
    }


    // read single block:    01 0d 0e 01 <block number>
    // read multiple blocks: 01 0d 0f 02 <start block> <end block>

    enum RequestType: String, CustomStringConvertible {
        case none         = ""
        case ack          = "81 0a 00"
        case sleep        = "01 0c 0e 00"
        case wakeupReply  = "01 0c 0f 00"
        case sensorInfo   = "01 0d 09 00"
        case fram         = "01 0d 0f 02 00 2b"
        case battery      = "01 0d 0a 00"
        case firmware     = "01 0d 0b 00"
        case patchUid     = "01 0e 00 03 26 01 00"
        case patchInfo    = "01 0e 00 03 02 a1 07"

        var description: String {
            switch self {
            case .none:        return "none"
            case .ack:         return "ack"
            case .sleep:       return "sleep"
            case .wakeupReply: return "wake up response"
            case .sensorInfo:  return "sensor info"
            case .fram:        return "fram"
            case .battery:     return "battery"
            case .firmware:    return "firmware"
            case .patchUid:    return "patch uid"
            case .patchInfo:   return "patch info"
            }
        }
    }

    var currentRequest: RequestType = .none

    func write(request: RequestType) {
        write(request.rawValue.bytes, .withResponse)
        currentRequest = request
        log("\(name): did write request for \(request)")
    }


    override func readCommand(interval: Int = 5) -> Data {
        return Data([0x00]) // TODO
    }


    override func read(_ data: Data, for uuid: String) {

        let dataHex = data.hex

        let response = ResponseType(rawValue: dataHex)
        log("\(name) response: \(response?.description ?? "data") (0x\(dataHex))")

        guard data.count > 0 else { return }

        if response == .timeout {
            main.status("\(name): timeout")
            write(request: .sleep)

        } else if response == .noSensor {
            main.status("\(name): no sensor")
            // write(request: .sleep) // FIXME: causes an immediate .wakeup

        } else if response == .wakeup {
            write(request: .sensorInfo)

        } else {
            // TODO: instantiate specifically a Libre2() (when detecting A4 in the uid, i. e.)
            if sensor == nil {
                sensor = Sensor(transmitter: self)
                main.app.sensor = sensor
            }
            if dataHex.hasPrefix(ResponseType.sensorInfo.rawValue) {
                sensorUid = Data(data[3...10])
                sensor!.uid = sensorUid
                main.settings.patchUid = sensorUid
                // FIXME: doesn't work with Libre 2
                if let sensorState = SensorState(rawValue: data[17]) {
                    sensor!.state = sensorState
                }
                log("\(name): patch uid: \(sensor!.uid.hex), serial number: \(sensor!.serial), sensor state: \(sensor!.state)")
                if sensor!.state == .active {
                    write(request: .ack)
                } else {
                    write(request: .sleep)
                }

            } else if response == .ack {
                if currentRequest == .ack {
                    write(request: .firmware)
                } else { // after a .sleep request
                    currentRequest = .none
                }

            } else if dataHex.hasPrefix(ResponseType.firmware.rawValue) {
                let firmware = dataHex.bytes.dropFirst(2).map { String($0) }.joined(separator: ".")
                self.firmware = firmware
                log("\(name): firmware: \(firmware)")
                write(request: .battery)

            } else if dataHex.hasPrefix(ResponseType.battery.rawValue) {
                if data[2] == 0xaa {
                    // battery = 100 // TODO
                } else if data[2] == 0x02 {
                    battery = 5
                }
                write(request: .patchInfo)
                // write(request: .patchUid) // will give same .patchUidInfo response type

            } else if dataHex.hasPrefix(ResponseType.patchUidInfo.rawValue) {
                if currentRequest == .patchInfo {
                    let patchInfo = Data(data[3...])
                    sensor!.patchInfo = patchInfo
                    main.settings.patchInfo = sensor!.patchInfo
                    log("\(name): patch info: \(sensor!.patchInfo.hex) (sensor type: \(sensor!.type.rawValue))")
                } else if currentRequest == .patchUid {
                    sensorUid = Data(data[4...])
                    sensor!.uid = sensorUid
                    main.settings.patchUid = sensorUid
                    main.settings.activeSensorSerial = sensor!.serial
                    log("\(name): patch uid: \(sensor!.uid.hex), serial number: \(sensor!.serial)")
                }
                write(request: .fram)

            } else if dataHex.hasPrefix(ResponseType.multipleBlocks.rawValue) {
                if buffer.count == 0 {
                    main.app.lastReadingDate = main.app.lastConnectionDate
                    sensor!.lastReadingDate = main.app.lastConnectionDate
                }
                buffer.append(data.suffix(from: 4))
                log("\(name): partial buffer size: \(buffer.count)")
                if buffer.count == 344 {
                    write(request: .sleep)
                    sensor!.fram = Data(buffer)
                    main.status("\(sensor!.type)  +  \(name)")
                }
            }
        }
    }
}


class Watlaa: Watch {
    // override class var type: DeviceType { DeviceType.watch(.watlaa) }
    override class var name: String { "Watlaa" }

    enum UUID: String, CustomStringConvertible, CaseIterable {
        case data           = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
        case dataWrite      = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
        case dataRead       = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
        case legacyData     = "00001010-1212-EFDE-0137-875F45AC0113"
        case legacyDataRead = "00001011-1212-EFDE-0137-875F45AC0113"
        case bridgeStatus   = "00001012-1212-EFDE-0137-875F45AC0113"
        case lastGlucose    = "00001013-1212-EFDE-0137-875F45AC0113"
        case calibration    = "00001014-1212-EFDE-0137-875F45AC0113"
        case glucoseUnit    = "00001015-1212-EFDE-0137-875F45AC0113"
        case alerts         = "00001016-1212-EFDE-0137-875F45AC0113"
        case unknown1       = "00001017-1212-EFDE-0137-875F45AC0113"
        case unknown2       = "00001018-1212-EFDE-0137-875F45AC0113"

        var description: String {
            switch self {
            case .data:           return "data"
            case .dataWrite:      return "data write"
            case .dataRead:       return "data read"
            case .legacyData:     return "data (legacy)"
            case .legacyDataRead: return "raw glucose data (legacy)"
            case .bridgeStatus:   return "bridge connection status"
            case .lastGlucose:    return "last glucose raw value"
            case .calibration:    return "calibration"
            case .glucoseUnit:    return "glucose unit"
            case .alerts:         return "alerts settings"
            case .unknown1:       return "unknown 1"
            case .unknown2:       return "unknown 2 (sensor serial)"
            }
        }
    }

    override class var knownUUIDs: [String] { UUID.allCases.map(\.rawValue) }

    override class var dataServiceUUID: String             { UUID.data.rawValue }
    override class var dataWriteCharacteristicUUID: String { UUID.dataWrite.rawValue }
    override class var dataReadCharacteristicUUID: String  { UUID.dataRead.rawValue }
    class var legacyDataServiceUUID: String                { UUID.legacyData.rawValue }
    class var legacyDataReadCharacteristicUUID: String     { UUID.legacyDataRead.rawValue }

    // Same as MiaoMiao
    enum ResponseType: UInt8, CustomStringConvertible {
        case dataPacket = 0x28
        case newSensor  = 0x32
        case noSensor   = 0x34
        case frequencyChange = 0xD1

        var description: String {
            switch self {
            case .dataPacket:      return "data packet"
            case .newSensor:       return "new sensor"
            case .noSensor:        return "no sensor"
            case .frequencyChange: return "frequency change"
            }
        }
    }

    enum BridgeStatus: UInt8, CustomStringConvertible {
        case notConnetced = 0x00
        case connectedInactiveSensor
        case connectedActiveSensor
        case unknown

        var description: String {
            switch self {
            case .notConnetced:            return "Not connected"
            case .connectedInactiveSensor: return "Connected: inactive sensor"
            case .connectedActiveSensor:   return "Connected: active sensor"
            case .unknown:                 return "Unknown"
            }
        }
    }

    @Published var bridgeStatus: BridgeStatus = .unknown

    @Published var slope: Float = 0.0 {
        didSet(slope) {
            if slope != self.slope && slope != 0.0 {
                writeAlertsSettings()
            }
        }
    }

    @Published var intercept: Float = 0.0 {
        didSet(intercept) {
            if intercept != self.intercept && intercept != 0.0 {
                writeAlertsSettings()
            }
        }
    }

    @Published var lastGlucose: Int = 0
    @Published var lastGlucoseAge: Int = 0

    @Published var unit: GlucoseUnit = .mgdl {
        didSet(unit) {
            if unit != self.unit {
                write([UInt8(GlucoseUnit.allCases.firstIndex(of: self.unit)!)], for: .glucoseUnit)
            }
        }
    }

    @Published var alarmHigh: Float = 0.0 {
        didSet(alarmHigh) {
            if alarmHigh != self.alarmHigh && alarmHigh != 0.0 {
                writeAlertsSettings()
            }
        }
    }

    @Published var alarmLow: Float = 0.0 {
        didSet(alarmLow) {
            if alarmLow != self.alarmLow && alarmLow != 0.0 {
                writeAlertsSettings()
            }
        }
    }
    @Published var connectionCheckInterval: Int = 0 {
        didSet(connectionCheckInterval) {
            if connectionCheckInterval != self.connectionCheckInterval && connectionCheckInterval != 0 {
                writeAlertsSettings()
            }
        }
    }
    @Published var snoozeLow: Int = 0 {
        didSet(snoozeLow) {
            if snoozeLow != self.snoozeLow && snoozeLow != 0 {
                writeAlertsSettings()
            }
        }
    }
    @Published var snoozeHigh: Int = 0 {
        didSet(snoozeHigh) {
            if snoozeHigh != self.snoozeHigh && snoozeHigh != 0 {
                writeAlertsSettings()
            }
        }
    }
    @Published var sensorLostVibration: Bool = true {
        didSet(sensorLostVibration) {
            if sensorLostVibration != self.sensorLostVibration {
                writeAlertsSettings()
            }
        }
    }
    @Published var glucoseVibration: Bool = true {
        didSet(glucoseVibration) {
            if glucoseVibration != self.glucoseVibration {
                writeAlertsSettings()
            }
        }
    }

    @Published var lastReadingDate: Date = Date()


    func writeAlertsSettings() {
        write([UInt8](withUnsafeBytes(of: &alarmHigh) { Data($0) }) +
              [UInt8](withUnsafeBytes(of: &alarmLow) { Data($0) }) +
              [UInt8(connectionCheckInterval & 0xFF)] +
              [UInt8((connectionCheckInterval >> 8) & 0xFF)] +
              [UInt8(snoozeLow) & 0xFF] +
              [UInt8((snoozeLow >> 8) & 0xFF)] +
              [UInt8(snoozeHigh & 0xFF)] +
              [UInt8((snoozeHigh >> 8) & 0xFF)] +
              [(UInt8(0) | (sensorLostVibration == true ? 8 : 0) | (glucoseVibration == true ? 2 : 0))],
              for: .alerts)
    }


    // TODO: implements in Device class
    func readValue(for uuid: UUID) {
        peripheral?.readValue(for: characteristics[uuid.rawValue]!)
        main.debugLog("\(name): requested value for \(uuid)")
    }

    func write(_ bytes: [UInt8], for uuid: UUID) {
        peripheral?.writeValue(Data(bytes), for: characteristics[uuid.rawValue]!, type: .withResponse)
        main.debugLog("\(name): written value 0x\(Data(bytes).hex) for \(uuid)")
    }


    // Same as MiaoMiao
    override func readCommand(interval: Int = 5) -> Data {
        var command = [UInt8(0xF0)]
        if [1, 3].contains(interval) {
            command.insert(contentsOf: [0xD1, UInt8(interval)], at: 0)
        }
        return Data(command)
    }


    override func read(_ data: Data, for uuid: String) {

        let description = UUID(rawValue: uuid)?.description ?? uuid
        main.log("\(name): received value for \(description) characteristic")

        switch UUID(rawValue: uuid) {


            // Same as MiaoMiao
        case .dataRead:
            let bridge = transmitter!
            let bridgeName = "\(transmitter!.name) + \(name)"

            let response = ResponseType(rawValue: data[0])
            if bridge.buffer.count == 0 {
                main.log("\(bridgeName) response: \(response?.description ?? "unknown") (0x\(data[0...0].hex))")
            }
            if data.count == 1 {
                if response == .noSensor {
                    main.status("\(bridgeName): no sensor")
                }
                // TODO: prompt the user and allow writing the command 0xD301 to change sensor
                if response == .newSensor {
                    main.status("\(bridgeName): detected a new sensor")
                }
            } else if data.count == 2 {
                if response == .frequencyChange {
                    if data[1] == 0x01 {
                        main.log("\(bridgeName): success changing frequency")
                    } else {
                        main.log("\(bridgeName): failed to change frequency")
                    }
                }
            } else {
                if bridge.sensor == nil {
                    bridge.sensor = Sensor(transmitter: bridge)
                    main.app.sensor = bridge.sensor
                }
                if bridge.buffer.count == 0 { bridge.sensor!.lastReadingDate = main.app.lastReadingDate }
                bridge.buffer.append(data)
                main.log("\(bridgeName): partial buffer size: \(bridge.buffer.count)")
                if bridge.buffer.count >= 363 {
                    main.log("\(bridgeName): data size: \(Int(bridge.buffer[1]) << 8 + Int(bridge.buffer[2]))")

                    bridge.battery  = Int(bridge.buffer[13])
                    bridge.firmware = bridge.buffer[14...15].hex
                    bridge.hardware = bridge.buffer[16...17].hex
                    main.log("\(bridgeName): battery: \(battery), firmware: \(firmware), hardware: \(hardware)")

                    bridge.sensor!.age = Int(bridge.buffer[3]) << 8 + Int(bridge.buffer[4])
                    let uid = Data(bridge.buffer[5...12])
                    if uid[5] != 0 {
                        bridge.sensor!.uid = uid
                    } else {
                        bridge.sensor!.uid = Data()
                    }
                    main.log("\(bridgeName): sensor age: \(bridge.sensor!.age) minutes (\(String(format: "%.1f", Double(bridge.sensor!.age)/60/24)) days), patch uid: \(uid.hex), serial number: \(bridge.sensor!.serial)")

                    if bridge.buffer.count > 369 {
                        bridge.sensor!.patchInfo = Data(bridge.buffer[363...368])
                        main.log("\(bridgeName): patch info: \(bridge.sensor!.patchInfo.hex)")
                    } else {
                        bridge.sensor!.patchInfo = Data([0xDF, 0x00, 0x00, 0x01, 0x01, 0x02])
                    }
                    bridge.sensor!.fram = Data(bridge.buffer[18 ..< 362])
                    readSetup()
                    main.status("\(bridge.sensor!.type)  +  \(bridgeName)")
                }
            }


        case .legacyDataRead:

            let bridge = transmitter!
            let bridgeName = "\(transmitter!.name) + \(name)"

            if bridge.sensor == nil {
                if main.app.sensor != nil {
                    bridge.sensor = main.app.sensor
                } else {
                    bridge.sensor = Sensor(transmitter: bridge)
                    main.app.sensor = bridge.sensor
                }
            }
            if bridge.buffer.count == 0 { bridge.sensor!.lastReadingDate = main.app.lastReadingDate }
            lastReadingDate = main.app.lastReadingDate
            bridge.buffer.append(data)
            main.log("\(bridgeName): partial buffer size: \(bridge.buffer.count)")

            if bridge.buffer.count == 344 {
                let fram = bridge.buffer[..<344]
                bridge.sensor!.fram = Data(fram)
                readSetup()
                main.status("\(bridge.sensor!.type)  +  \(bridgeName)")
            }


        case .lastGlucose:
            let value = Int(data[1]) << 8 + Int(data[0])
            let age   = Int(data[3]) << 8 + Int(data[2])
            lastGlucose = value
            lastGlucoseAge = age
            main.log("\(name): last raw glucose: \(value), age: \(age) minutes")

        case .calibration:
            let slope:     Float = Data(data[0...3]).withUnsafeBytes { $0.load(as: Float.self) }
            let intercept: Float = Data(data[4...7]).withUnsafeBytes { $0.load(as: Float.self) }
            self.slope = slope
            self.intercept = intercept
            main.log("\(name): slope: \(slope), intercept: \(intercept)")

        case .glucoseUnit:
            if let unit = GlucoseUnit(rawValue: GlucoseUnit.allCases[Int(data[0])].rawValue) {
                main.log("\(name): glucose unit: \(unit)")
                self.unit = unit
            }

        case .bridgeStatus:
            bridgeStatus = data[0] < BridgeStatus.unknown.rawValue ? BridgeStatus(rawValue: data[0])! : .unknown
            main.log("\(name): transmitter status: \(bridgeStatus.description)")

        case .alerts:
            alarmHigh = Data(data[0...3]).withUnsafeBytes { $0.load(as: Float.self) }
            alarmLow  = Data(data[4...7]).withUnsafeBytes { $0.load(as: Float.self) }
            connectionCheckInterval = Int(data[ 9]) << 8 + Int(data[ 8])
            snoozeLow               = Int(data[11]) << 8 + Int(data[10])
            snoozeHigh              = Int(data[13]) << 8 + Int(data[12])
            let signals: UInt8 = data[14]
            sensorLostVibration = (signals >> 3) & 1 == 1
            glucoseVibration    = (signals >> 1) & 1 == 1

            main.log("\(name): alerts: high: \(alarmHigh), low: \(alarmLow), bridge connection check: \(connectionCheckInterval) minutes, snooze low: \(snoozeLow) minutes, snooze high: \(snoozeHigh) minutes, sensor lost vibration: \(sensorLostVibration), glucose vibration: \(glucoseVibration)")

        case .unknown2:
            var sensorSerial = data.string
            if sensorSerial.prefix(2) != "00" {
                transmitter?.sensor?.serial = sensorSerial
            } else {
                sensorSerial = "N/A"
            }
            main.log("\(name): sensor serial number: \(sensorSerial)")

        default:
            break
        }
    }


    func readSetup() {
        readValue(for: .calibration)
        readValue(for: .glucoseUnit)
        readValue(for: .lastGlucose)
        readValue(for: .bridgeStatus)
        readValue(for: .alerts)
        readValue(for: .unknown2) // sensor serial
    }
}


#if !os(watchOS)

struct WatlaaDetailsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: Settings

    @ObservedObject var device: Watlaa = Watlaa()

    var body: some View {
        Group {
            Section {
                HStack {
                    Text("Bridge status")
                    Spacer()
                    Text(device.bridgeStatus.description)
                        .foregroundColor(device.bridgeStatus == .connectedActiveSensor ? .green : .red)
                }
                if !(device.transmitter?.sensor?.serial.isEmpty ?? true) {
                    HStack {
                        Text("Sensor serial")
                        Spacer()
                        Text(device.transmitter!.sensor!.serial).foregroundColor(.yellow)
                    }
                }
            }

            Section(header: Text("SETUP").font(.headline)) {
                HStack {
                    Text("Unit")
                    Spacer().frame(maxWidth: .infinity)
                    Picker(selection: $device.unit, label: Text("Unit")) {
                        ForEach(GlucoseUnit.allCases) { unit in
                            Text(unit.description).tag(unit)
                        }
                    }.pickerStyle(SegmentedPickerStyle())
                }
            }

            Section(header: Text("Calibration")) {
                Group {
                    HStack {
                        Text("Intercept")
                        Spacer().frame(maxWidth: .infinity)
                        TextField("Intercept", value: $device.intercept, formatter: settings.numberFormatter)
                            .foregroundColor(.purple)
                    }
                    HStack {
                        Text("Slope")
                        Spacer().frame(maxWidth: .infinity)
                        TextField("Slope", value: $device.slope, formatter: settings.numberFormatter)
                            .foregroundColor(.purple)
                    }
                }.keyboardType(.numbersAndPunctuation)
            }

            Section(header: Text("Alarms")) {
                HStack {
                    Image(systemName: "bell.fill")
                    Spacer().frame(maxWidth: .infinity)
                    Text(" > ")
                    TextField("High", value: $device.alarmHigh, formatter: NumberFormatter())
                    Text("   < ")
                    TextField("Low", value: $device.alarmLow, formatter: NumberFormatter())
                    // FIXME: doesn't update when changing unit
                    Text(" \(device.unit.description)")
                }.foregroundColor(.red)
                HStack {
                    Image(systemName: "speaker.zzz.fill")
                    Spacer().frame(maxWidth: .infinity)
                    Text("High: ")
                    TextField("High", value: $device.snoozeHigh, formatter: NumberFormatter())
                    Text("Low: ")
                    TextField("Low", value: $device.snoozeLow, formatter: NumberFormatter())
                    Text(" min")
                }.foregroundColor(.yellow)
            }
            Section(header: Text("Vibrations")) {
                HStack {
                    Text("Sensor lost")
                    Toggle("Sensor lost", isOn: $device.sensorLostVibration).labelsHidden()
                    Spacer()
                    Text("Glucose")
                    Toggle("Glucose", isOn: $device.glucoseVibration).labelsHidden()
                }
            }
            HStack {
                Text("Bridge check interval").layoutPriority(1.0)
                Spacer().frame(maxWidth: .infinity)
                TextField("Interval", value: $device.connectionCheckInterval, formatter: NumberFormatter())
                Text(" min")
            }
            // TODO: spacer to allow editing
        }
    }
}


struct Watch_Previews: PreviewProvider {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: Settings
    static var previews: some View {
        Group {
            WatlaaDetailsView(device: Watlaa())
                .environmentObject(AppState.test(tab: .monitor))
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}

#endif


// Legacy code from bluetoothDelegate didDiscoverCharacteristicsFor:

// if app.device.type == .watch(.watlaa) && serviceUUID == Watlaa.dataServiceUUID {
//     (app.device as! Watlaa).readSetup()
//     log("Watlaa: reading configuration")
// }
