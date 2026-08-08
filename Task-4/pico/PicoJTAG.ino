#include "jtag.h"
#include "dtm.h"

void setup() {
    Serial.begin(115200);
    delay(1000);

    jtag_init();
    Serial.println();
    Serial.println("========================================");
    Serial.println("Task 4: Standard RISC-V Debug Probe");
    Serial.println("========================================");

    bool passed = run_task4_hardware_probe();

    Serial.println("========================================");

    if (passed) {
        Serial.println("TASK 4 HARDWARE PASSED");
    } else {
        Serial.println("TASK 4 HARDWARE FAILED");
    }

    Serial.println("========================================");
    
}

void loop() {
}
