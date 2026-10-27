import Foundation
import Testing

struct LidBluetoothTests {
    @Test(arguments: ["bc:87:fa:27:b0:8d", "BC:87:FA:27:B0:8D", "bc-87-fa-27-b0-8d"])
    func addressFormsNormalize(text: String) {
        #expect(BluetoothAddress(text)?.value == "bc:87:fa:27:b0:8d")
    }

    @Test(arguments: ["", "bc:87:fa:27:b0", "bc:87:fa:27:b0:8d:00", "zz:87:fa:27:b0:8d", "bc87fa27b08d"])
    func malformedAddressesAreRejected(text: String) {
        #expect(BluetoothAddress(text) == nil)
    }

    @Test
    func addressEncodesAsItsString() throws {
        let address = try #require(BluetoothAddress("BC:87:FA:27:B0:8D"))
        let data = try JSONEncoder().encode([address])
        #expect(String(bytes: data, encoding: .utf8) == #"["bc:87:fa:27:b0:8d"]"#)
        #expect(try JSONDecoder().decode([BluetoothAddress].self, from: data) == [address])
    }

    @Test
    func listsConnectedDevicesFirstAndDropsDuplicates() throws {
        let json = """
            {"SPBluetoothDataType":[{"controller_properties":{},
              "device_connected":[{"Bose QC Ultra":{"device_address":"BC:87:FA:27:B0:8D"}}],
              "device_not_connected":[{"EDIFIER":{"device_address":"60:F4:3A:31:77:20"}},
                {"AirPods Pro":{"device_address":"20:E2:A8:45:7A:63"}},
                {"Bose QC Ultra":{"device_address":"BC:87:FA:27:B0:8D"}}]}]}
            """
        let devices = try BluetoothDevice.list(fromSystemProfilerJSON: Data(json.utf8))
        #expect(devices.map(\.name) == ["Bose QC Ultra", "AirPods Pro", "EDIFIER"])
        #expect(devices.map(\.isConnected) == [true, false, false])
    }

    @Test
    func noPairedDevicesIsAnEmptyList() throws {
        let json = #"{"SPBluetoothDataType":[{"controller_properties":{}}]}"#
        #expect(try BluetoothDevice.list(fromSystemProfilerJSON: Data(json.utf8)).isEmpty)
    }
}
