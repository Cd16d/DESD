import serial
import serial.tools.list_ports
import time
import queue
import threading
import matplotlib.pyplot as plt
import matplotlib.animation as animation

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

def receive_graph_mode(ser):
    print("Modalità ricezione e visualizzazione coordinate in tempo reale. Premi Ctrl+C per uscire.\n")
    q = queue.Queue()

    def serial_reader():
        while True:
            if ser.in_waiting >= CHUNK_SIZE:
                data = ser.read(CHUNK_SIZE)
                if len(data) >= 4:
                    x = data[1]
                    y = data[2]
                    flags = data[3]
                    q.put((x, y, flags))

    reader_thread = threading.Thread(target=serial_reader, daemon=True)
    reader_thread.start()

    latest_point = [64, 64]  # Punto iniziale al centro del grafico
    latest_color = 'blue'
    latest_size = 100

    fig, ax = plt.subplots()
    sc = ax.scatter([latest_point[0]], [latest_point[1]], c=[latest_color], s=[latest_size])
    ax.set_xlim(0, 127)
    ax.set_ylim(0, 127)
    ax.set_xlabel("X")
    ax.set_ylabel("Y")
    ax.set_title("Coordinate in tempo reale")

    def update(frame):
        nonlocal latest_point, latest_color, latest_size
        while not q.empty():
            x, y, flags = q.get()
            latest_point[0] = x
            latest_point[1] = y
            # Bit 0: red if set, else blue
            if flags & 0b00000001:
                latest_color = 'red'
            else:
                latest_color = 'blue'
            # Bit 1: bigger if set
            if flags & 0b00000010:
                latest_size = 300
            else:
                latest_size = 100
        sc.set_offsets([latest_point])
        sc.set_color([latest_color])
        sc.set_sizes([latest_size])
        return sc,

    ani = animation.FuncAnimation(fig, update, interval=10, blit=True, cache_frame_data=False)
    plt.show()

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
    while mode not in ["r", "s", "g"]:
        mode = input("Vuoi ricevere (r), inviare (s), o ricevere con grafico (g)? [r/s/g]: ").strip().lower()

    ser = serial.Serial(PORT, BAUDRATE, timeout=1)
    print(f"Aperta porta seriale: {PORT} a {BAUDRATE} baud.\n")

    if mode == "r":
        receive_mode(ser)
    elif mode == "s":
        send_mode(ser)
    elif mode == "g":
        receive_graph_mode(ser)
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
