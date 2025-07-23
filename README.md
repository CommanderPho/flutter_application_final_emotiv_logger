# flutter_application_final_emotiv_logger

A new Flutter project that tries to decrypt Emotiv Epoc X (or Emotiv Epoc+) data over BLE and stream it over the network via LabStreamingLayer (LSL).

Should work on Android, iOS, linux, and more!


## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.



## Capturing Bluetooth Emotiv EEG Logs


### Transfer the log to your computer
```bash
PS C:\Users\pho\bin\platform-tools> .\adb bugreport 2025-07-22_bt_bugreport.zip
/data/user_de/0/com.android.shell/files/bugreports/bugreport-lineage_walleye-BP1A.250505.005-2025-07-22-19-31-22.zip: 1 file pulled, 0 skipped. 27.1 MB/s (12042426 bytes in 0.423s)
Bug report copied to 2025-07-22_bt_bugreport.zip

```
Extract the zip and find the `btsnoop_hci.log` file:
```bash
"C:\Users\pho\repos\EmotivEpoc\flutter_application_final_emotiv_logger\EXTERNAL\Emotiv_Epoc_Reverse_Engineering\2025-07-22_bt_bugreport\FS\data\misc\bluetooth\logs\btsnoop_hci.log"

btsnooz.py BUG_REPORT.txt > BTSNOOP.log


btsnooz.py C:\Users\pho\repos\EmotivEpoc\flutter_application_final_emotiv_logger\EXTERNAL\Emotiv_Epoc_Reverse_Engineering\2025-07-22_bt_bugreport\FS\data\misc\bluetooth\logs\btsnoop_hci.log > BTSNOOP.plaintext.log

"C:\Users\pho\repos\EmotivEpoc\flutter_application_final_emotiv_logger\EXTERNAL\Emotiv_Epoc_Reverse_Engineering\fluoride\Bluetooth\system\tools\scripts\btsnooz.py" C:\Users\pho\repos\EmotivEpoc\flutter_application_final_emotiv_logger\EXTERNAL\Emotiv_Epoc_Reverse_Engineering\2025-07-22_bt_bugreport\FS\data\misc\bluetooth\logs\btsnoop_hci.log > BTSNOOP.plaintext.log


"C:\Users\pho\repos\EmotivEpoc\flutter_application_final_emotiv_logger\EXTERNAL\Emotiv_Epoc_Reverse_Engineering\fluoride\Bluetooth\system\tools\scripts\btsnooz.py" "C:\Users\pho\repos\EmotivEpoc\flutter_application_final_emotiv_logger\EXTERNAL\Emotiv_Epoc_Reverse_Engineering\2025-07-22_bt_bugreport\bugreport-lineage_walleye-BP1A.250505.005-2025-07-22-19-31-22.txt" > BTSNOOP.plaintext.log


"C:\Users\pho\repos\EmotivEpoc\flutter_application_final_emotiv_logger\EXTERNAL\Emotiv_Epoc_Reverse_Engineering\fluoride\Bluetooth\system\tools\scripts\btsnooz.py" "C:\Users\pho\repos\EmotivEpoc\flutter_application_final_emotiv_logger\EXTERNAL\Emotiv_Epoc_Reverse_Engineering\bugreport-lineage_walleye-BP1A.250505.005-2025-07-22-20-08-12\bugreport-lineage_walleye-BP1A.250505.005-2025-07-22-20-08-12.txt" > BTSNOOP.plaintext.log


```

https://stackoverflow.com/questions/28445552/bluetooth-hci-snoop-log-not-generated/30352487#30352487
https://cs.android.com/android/platform/superproject/+/android-latest-release:packages/modules/Bluetooth/system/tools/scripts/btsnooz.py

## For WSL on Windows:
```bash

sudo apt install git gnupg flex bison gperf build-essential \
  zip curl zlib1g-dev gcc-multilib g++-multilib \
  x11proto-core-dev libx11-dev libncurses5 \
  libgl1-mesa-dev libxml2-utils xsltproc unzip liblz4-tool libssl-dev \
  libc++-dev libevent-dev \
  flatbuffers-compiler libflatbuffers1 openssl \
  libflatbuffers-dev libfmt-dev libtinyxml2-dev \
  libglib2.0-dev libevent-dev libnss3-dev libdbus-1-dev \
  libprotobuf-dev ninja-build generate-ninja protobuf-compiler \
  libre2-9 debmake \
  llvm libc++abi-dev \
  libre2-dev libdouble-conversion-dev \
  libgtest-dev libgmock-dev libabsl-dev

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  ```