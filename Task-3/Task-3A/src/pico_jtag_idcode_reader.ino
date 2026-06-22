// =====================================================
// Raspberry Pi Pico JTAG IDCODE Reader
// FPGA Expected IDCODE = 0x81262776
// =====================================================

const int TCK  = 0;
const int TMS  = 1;
const int TDI  = 2;
const int TDO  = 3;
const int TRST = 4;

void pulseTCK()
{
    digitalWrite(TCK, HIGH);
    delayMicroseconds(10);

    digitalWrite(TCK, LOW);
    delayMicroseconds(10);
}

void jtagClock(bool tms, bool tdi)
{
    digitalWrite(TMS, tms);
    digitalWrite(TDI, tdi);

    delayMicroseconds(10);

    pulseTCK();
}

void tapReset()
{
    digitalWrite(TRST, HIGH);
    delay(20);

    digitalWrite(TRST, LOW);
    delay(20);

    // Force TAP reset
    for (int i = 0; i < 6; i++)
        jtagClock(1, 0);

    // Run-Test/Idle
    jtagClock(0, 0);
}

void loadIDCODEInstruction()
{
    // Select DR
    jtagClock(1, 0);

    // Select IR
    jtagClock(1, 0);

    // Capture IR
    jtagClock(0, 0);

    // Shift IR
    jtagClock(0, 0);

    // IDCODE = 0001 (LSB first)
    jtagClock(0, 1); // bit0
    jtagClock(0, 0); // bit1
    jtagClock(0, 0); // bit2
    jtagClock(1, 0); // bit3 + Exit1IR

    // Update IR
    jtagClock(1, 0);

    // Idle
    jtagClock(0, 0);
}

uint32_t readIDCODE()
{
    uint32_t value = 0;

    // Select DR
    jtagClock(1, 0);

    // Capture DR
    jtagClock(0, 0);

    // Shift DR
    jtagClock(0, 0);

    Serial.println("Bits:");

    for (int i = 0; i < 32; i++)
    {
        bool lastBit = (i == 31);

        digitalWrite(TMS, lastBit);
        digitalWrite(TDI, LOW);

        // Rising edge causes shift
        digitalWrite(TCK, HIGH);
        delayMicroseconds(10);

        // Falling edge
        digitalWrite(TCK, LOW);
        delayMicroseconds(10);

        // Sample after falling edge
        int bit = digitalRead(TDO);

        Serial.print(bit);

        if (bit)
            value |= (1UL << i);
    }

    Serial.println();

    // Update DR
    jtagClock(1, 0);

    // Idle
    jtagClock(0, 0);

    return value;
}

void setup()
{
    pinMode(TCK, OUTPUT);
    pinMode(TMS, OUTPUT);
    pinMode(TDI, OUTPUT);
    pinMode(TRST, OUTPUT);
    pinMode(TDO, INPUT);

    digitalWrite(TCK, LOW);
    digitalWrite(TMS, HIGH);
    digitalWrite(TDI, LOW);
    digitalWrite(TRST, LOW);

    Serial.begin(115200);

    while (!Serial)
        delay(10);

    Serial.println();
    Serial.println("================================");
    Serial.println("Pico JTAG IDCODE Reader");
    Serial.println("================================");

    tapReset();

    loadIDCODEInstruction();

    uint32_t idcode = readIDCODE();

    Serial.print("IDCODE = 0x");
    Serial.println(idcode, HEX);

    if (idcode == 0x81262776)
        Serial.println("TASK 3A PASSED");
    else
        Serial.println("IDCODE MISMATCH");
}

void loop()
{
}