// Private IOBluetooth functions that switch the Bluetooth radio, the same ones Bluesnooze and blueutil use.
// 1 is on, 0 is off.
int IOBluetoothPreferenceGetControllerPowerState(void);
void IOBluetoothPreferenceSetControllerPowerState(int state);
