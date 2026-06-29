// =====================================================
// Raspberry Pi Pico JTAG IDCODE Reader
// FPGA Expected IDCODE = 0x81262776
// =====================================================

const int TCK  = 5;
const int TMS  = 6;
const int TDI  = 8;
const int TDO  = 10;
const int TRST = 12;

#define IDCODE        0x1
#define DEBUG_CTRL    0x2
#define DEBUG_STATUS  0x3
#define DEBUG_PC      0x4

#define CTRL_HALT   0x1
#define CTRL_RESUME 0x2
#define CTRL_RESET  0x4

void pulseTCK()
{
    digitalWrite(TCK, HIGH);
    delayMicroseconds(1);

    digitalWrite(TCK, LOW);
    delayMicroseconds(1);
}

void jtagClock(bool tms, bool tdi)
{
    digitalWrite(TMS, tms);
    digitalWrite(TDI, tdi);

    delayMicroseconds(1);

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

void loadInstruction(uint8_t instruction)
{
    // Select DR
    jtagClock(1, 0);

    // Select IR
    jtagClock(1, 0);

    // Capture IR
    jtagClock(0, 0);

    // Shift IR
    jtagClock(0, 0);

    // Shift 4-bit instruction (LSB first)
    for (int i = 0; i < 4; i++)
    {
        bool last = (i == 3);

        jtagClock(last, (instruction >> i) & 1);
    }

    // Update IR
    jtagClock(1, 0);

    // Idle
    jtagClock(0, 0);
}

uint32_t readDR()
{
    uint32_t value = 0;

    // Select DR
    jtagClock(1, 0);

    // Capture DR
    jtagClock(0, 0);

    // Shift DR
    jtagClock(0, 0);

    for (int i = 0; i < 32; i++)
    {
        bool last = (i == 31);

        digitalWrite(TMS, last);
        digitalWrite(TDI, LOW);

        digitalWrite(TCK, HIGH);
        delayMicroseconds(1);

        digitalWrite(TCK, LOW);
        delayMicroseconds(1);

        if (digitalRead(TDO))
            value |= (1UL << i);
    }

    // Update DR
    jtagClock(1, 0);

    // Idle
    jtagClock(0, 0);

    return value;
}

void writeDR(uint32_t value)
{
    // Select DR
    jtagClock(1, 0);

    // Capture DR
    jtagClock(0, 0);

    // Shift DR
    jtagClock(0, 0);

    for (int i = 0; i < 32; i++)
    {
        bool last = (i == 31);

        jtagClock(last, (value >> i) & 1);
    }

    // Update DR
    jtagClock(1, 0);

    // Idle
    jtagClock(0, 0);
}

uint32_t readRegister(uint8_t instr)
{
    loadInstruction(instr);
    return readDR();
}

void writeRegister(uint8_t instr, uint32_t value)
{
    loadInstruction(instr);
    writeDR(value);
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

    Serial.println("Task 3C");
	Serial.println();

	Serial.println("Reading IDCODE...");
	loadInstruction(IDCODE);
	Serial.print("IDCODE = 0x");
	Serial.println(readDR(), HEX);

	Serial.println();

	Serial.println("Reading DEBUG_STATUS...");
	loadInstruction(DEBUG_STATUS);
	Serial.print("STATUS = 0x");
	Serial.println(readDR(), HEX);

	Serial.println();

	Serial.println("Reading DEBUG_PC...");
	loadInstruction(DEBUG_PC);
	Serial.print("PC = 0x");
	Serial.println(readDR(), HEX);

	//------------------------------------------------------
    // Verify PC is running
    //------------------------------------------------------

    //------------------------------------------------------
    // CPU RUN TEST
    //------------------------------------------------------

    Serial.println();
    Serial.println("CPU RUN TEST");

    uint32_t last = readRegister(DEBUG_PC);

    Serial.print("PC = 0x");
    Serial.println(last, HEX);

    bool running = false;

    for (int i = 0; i < 10; i++)
    {
        delay(20);

        uint32_t now = readRegister(DEBUG_PC);

        Serial.print("PC = 0x");
        Serial.println(now, HEX);

        if (now != last)
        {
            running = true;
            break;
        }

        last = now;
    }

    if (running)
        Serial.println("PASS : CPU Running");
    else
        Serial.println("FAIL : CPU Not Running");

    //------------------------------------------------------
    // HALT TEST
    //------------------------------------------------------

    Serial.println();
    Serial.println("Sending HALT");

    writeRegister(DEBUG_CTRL, CTRL_HALT);
    delay(5);
    writeRegister(DEBUG_CTRL, 0);

    delay(100);

    Serial.print("STATUS = 0x");
    Serial.println(readRegister(DEBUG_STATUS), HEX);

    uint32_t pc1 = readRegister(DEBUG_PC);

    Serial.print("PC Before Halt = 0x");
    Serial.println(pc1, HEX);

    delay(500);

    uint32_t pc2 = readRegister(DEBUG_PC);

    Serial.print("PC After Halt  = 0x");
    Serial.println(pc2, HEX);

    if (pc1 == pc2)
        Serial.println("PASS : CPU Halted");
    else
        Serial.println("FAIL : CPU Still Running");

    //------------------------------------------------------
    // RESUME TEST
    //------------------------------------------------------

    Serial.println();
    Serial.println("Sending RESUME");

    writeRegister(DEBUG_CTRL, CTRL_RESUME);
    delay(5);
    writeRegister(DEBUG_CTRL, 0);

    delay(100);

    Serial.print("STATUS = 0x");
    Serial.println(readRegister(DEBUG_STATUS), HEX);

    pc1 = readRegister(DEBUG_PC);

    Serial.print("PC Before Resume = 0x");
    Serial.println(pc1, HEX);

    delay(500);

    pc2 = readRegister(DEBUG_PC);

    Serial.print("PC After Resume  = 0x");
    Serial.println(pc2, HEX);

    if (pc1 != pc2)
        Serial.println("PASS : CPU Resumed");
    else
        Serial.println("FAIL : CPU Still Halted");

    // for(int i=0;i<10;i++)
    // {
    //     Serial.print("PC = 0x");
    //     Serial.println(readRegister(DEBUG_PC), HEX);
    //     delay(20);
    // }

    //------------------------------------------------------
    // RESET
    //------------------------------------------------------

    Serial.println();
    Serial.println("Sending RESET");

    writeRegister(DEBUG_CTRL, CTRL_RESET);
    delay(5);
    writeRegister(DEBUG_CTRL, 0);
    delay(10);

    for (int i = 0; i < 5; i++) {
        Serial.print("PC = 0x");
        Serial.println(readRegister(DEBUG_PC), HEX);
        delay(20);
    }

    delay(10);

    Serial.print("STATUS = 0x");
    Serial.println(readRegister(DEBUG_STATUS), HEX);

    Serial.print("PC After Reset = 0x");
    Serial.println(readRegister(DEBUG_PC), HEX);

    Serial.println();
    Serial.println("TASK 3C COMPLETE");
}

void loop()
{
}
