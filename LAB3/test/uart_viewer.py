import serial
import serial.tools.list_ports
import time
import queue
import threading
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import io
from PIL import Image
import numpy as np

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

    point = [64, 64]  # Punto iniziale al centro del grafico
    color = 'blue'
    size = 100

    release = True
    rgb = [0, 0, 0]

    fig, ax = plt.subplots()

    # Load PNG directly
    png_path = r'LAB3\test\Color_circle_(RGB).png'
    img = Image.open(png_path).convert('RGB')
    img = img.resize((127, 127), Image.Resampling.LANCZOS)  # Ensure image is 127x127
    img_np = np.array(img)

    # Show the image as background
    ax.imshow(img, extent=(0, 127, 0, 127), aspect='auto', zorder=0)

    sc = ax.scatter([point[0]], [point[1]], s=[size], zorder=1)
    ax.set_xlim(0, 127)
    ax.set_ylim(0, 127)
    ax.set_xlabel("X")
    ax.set_ylabel("Y")
    ax.set_title("Coordinate in tempo reale")

    def send_rgb_over_serial(ser, rgb):
        """
        Send RGB values over serial with a fixed first byte (0xC0).
        """
        bytes_to_send = [0xC0]  # Primo byte fisso
        for part in rgb:
            val = int(part)
            bytes_to_send.append(val)
        ser.write(bytearray(bytes_to_send))
        print(f"Inviato: {' '.join(f'{b:02X}' for b in bytes_to_send)}")

    def update(frame):
        nonlocal point, color, size, release, rgb

        while not q.empty():
            x, y, flags = q.get()
            point[0] = x
            point[1] = y

            if flags & 0b00000001:
                rgb = [0, 0, 0]
                size = 50
                if release:
                    send_rgb_over_serial(ser, rgb)
                    release = False

            elif flags & 0b00000010:
                flipped_y = 127 - y # Flip y to match image coordinates
                rgb = img_np[flipped_y, x]
                size = 300
                if release:
                    send_rgb_over_serial(ser, rgb)
                    release = False

            else:
                size = 100
                release = True  # Reset release when no button is pressed

        sc.set_offsets([point])
        sc.set_sizes([size])
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

ser = None
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
    if ser is not None and ser.is_open:
        ser.close()
