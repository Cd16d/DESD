import serial
import serial.tools.list_ports
import time

# CONFIGURAZIONE
BASYS3_PID = 0x6010
BASYS3_VID = 0x0403
BAUDRATE = 115200      # Imposta la tua velocità
CHUNK_SIZE = 4         # 4 byte per riga

# Ricerca automatica della porta Basys3
dev = ""
for port in serial.tools.list_ports.comports():
    if (port.vid == BASYS3_VID and port.pid == BASYS3_PID):
        dev = port.device

if not dev:
    raise RuntimeError("Basys 3 Not Found!")

PORT = dev

def receive_mode(ser):
    print("Modalità ricezione. Premi Ctrl+C per uscire.\n")
    while True:
        if ser.in_waiting >= CHUNK_SIZE:
            data = ser.read(CHUNK_SIZE)
            hex_bytes = ' '.join(f"{b:02X}" for b in data)
            print(f"HH | {hex_bytes}")

def send_mode(ser):
    print("Modalità invio. Inserisci 3 byte in esadecimale (il primo sarà sempre 'C0').")
    print("Formato: XX XX XX (dove XX è tra 00 e FF). Premi Ctrl+C per uscire.\n")
    while True:
        try:
            user_input = input("Inserisci 3 byte (es: 12 34 AB): ").strip()
            parts = user_input.split()
            if len(parts) != 3:
                print("Devi inserire esattamente 3 byte.")
                continue
            try:
                bytes_to_send = [0xC0]  # Primo byte fisso
                for part in parts:
                    val = int(part, 16)
                    if not (0x00 <= val <= 0xFF):
                        raise ValueError
                    bytes_to_send.append(val)
                ser.write(bytearray(bytes_to_send))
                print(f"Inviato: {' '.join(f'{b:02X}' for b in bytes_to_send)}")
            except ValueError:
                print("Valori non validi. Usa solo byte esadecimali tra 00 e FF.")
        except KeyboardInterrupt:
            print("\nChiusura modalità invio...")
            break

try:
    mode = ""
    while mode not in ["r", "s", "4"]:
        mode = input("Vuoi ricevere (r), inviare (s) ? [r/s]: ").strip().lower()

    ser = serial.Serial(PORT, BAUDRATE, timeout=1)
    print(f"Aperta porta seriale: {PORT} a {BAUDRATE} baud.\n")

    if mode == "r":
        receive_mode(ser)
    elif mode == "s":
        send_mode(ser)
    else:
        print("Selezione non valida. Uscita...")
        ser.close()
        exit(1)

except KeyboardInterrupt:
    print("\nChiusura programma...")
except serial.SerialException as e:
    print(f"Errore nella connessione seriale: {e}")
finally:
    if 'ser' in locals() and ser.is_open:
        ser.close()
