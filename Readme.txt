=== WINDOWS ===

Step 1:
Right click "setup.cmd" and choose "Run as administrator", then wait till it
finish running. It installs Node.js, Appium and the UiAutomator2 driver.

Step 2:
Click on the "automation.exe" file to run


=== LINUX ===

Step 1:
Open a terminal in this folder and run:  ./setup.sh
Do NOT run it as root. It installs Node.js (via your package manager), Appium
and the UiAutomator2 driver, makes the bundled adb executable, and sets
ANDROID_HOME. When it finishes, open a new terminal (or run
"source ~/.profile") so ANDROID_HOME takes effect.

Step 2:
In the terminal, run:  ./automation
(If it reports "permission denied", run "chmod +x automation" once first.)


Notes:
- The automation program does not need Node.js or Appium. It drives the phones
  through the adb bundled in this folder. Those are installed for running the
  NUnit tests (UnitTest1.cs) only.

- The program is named "automation.exe" on Windows and "automation" on Linux.
  Where a command below shows one name, use the other on your platform.

- Do not run the automation program and an Appium server against the same phone
  at the same time. Android gives the screen-reading connection to one program
  at a time, so an Appium session takes it away and every screen read fails.
  Stop one before starting the other.

- To check a phone without running a transfer, open a command/terminal window in
  this folder and run:
      Windows:  automation.exe selftest
      Linux:    ./automation selftest
  It reads each connected phone's screen and prints the result. It does not open
  any app or tap anything.
