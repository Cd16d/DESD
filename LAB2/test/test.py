import sys
import subprocess

def install_and_import(package, package_name=None):
    if package_name is None:
        package_name = package
    import importlib
    try:
        importlib.import_module(package)
    except ImportError:
        subprocess.check_call([sys.executable, "-m", "pip", "install", package_name])
    finally:
        globals()[package] = importlib.import_module(package)

install_and_import("serial", "pyserial")
install_and_import("PIL", "pillow")
install_and_import("tqdm")
install_and_import("numpy")
install_and_import("scipy")

from serial import Serial
import serial.tools.list_ports
from tqdm import tqdm
from PIL import Image
from scipy.signal import convolve2d
import numpy as np

IMAGE_OF = r'C:\DESD\LAB2\test\test_of.png'
IMAGE_UF = r'C:\DESD\LAB2\test\test_uf.png'
IMAGE_NAME3 = r'C:\DESD\LAB2\test\test3.png'
IMAGE_NAME2 = r'C:\DESD\LAB2\test\test2.png'
IMAGE_NAME1 = r'C:\DESD\LAB2\test\test1.png'
IMAGE_DEPACK_PACK = r'C:\DESD\LAB2\test\test_depack_pack.png'

BASYS3_PID = 0x6010
BASYS3_VID = 0x0403

IMG_HEIGHT = 256
IMG_WIDTH = 256

dev = ""
for port in serial.tools.list_ports.comports():
    if (port.vid == BASYS3_VID and port.pid == BASYS3_PID):
        dev = port.device

if not dev:
    raise RuntimeError("Basys 3 Not Found!")

test_n = int(input("Insert test number (1, 2, 3, 4 (overflow), 5 (underflow) or 6 (depack > pack only)): ").strip())

if test_n not in [1, 2, 3, 4, 5, 6]:
    raise RuntimeError("Test number must be 1, 2, 3, 4 (overflow), 5 (underflow) or 6 (depack > pack only)")

dev = Serial(dev, 115200)

img = Image.open(IMAGE_NAME1 if test_n == 1 else IMAGE_NAME2 if test_n == 2 else IMAGE_NAME3 if test_n == 3 else IMAGE_OF if test_n == 4 else IMAGE_UF if test_n == 5 else IMAGE_DEPACK_PACK)
if img.mode != "RGB":
    img = img.convert("RGB")

if test_n == 4:
    print("Check for overflow (LED U16)")
elif test_n == 5:
    print("Check for underflow (LED U19)")

IMG_WIDTH, IMG_HEIGHT = img.size  # Get dimensions from the image

mat = np.asarray(img, dtype=np.uint8)

mat = mat[:, :, :3]
if mat.max() > 127:
    mat = mat // 2

res = b''

if test_n == 6:
    print("Check for depack > pack")

    total_bytes = IMG_HEIGHT * IMG_WIDTH * 3
    for idx in tqdm(range(total_bytes)):
        i = idx // (IMG_WIDTH * 3)
        j = (idx // 3) % IMG_WIDTH
        k = idx % 3

        dev.write(b'\xff')
        dev.write(bytes([mat[i, j, k]]))
        dev.write(b'\xf1')
        dev.flush()

        # Read 3 bytes: header, data, footer
        resp = dev.read(3)
        res += resp[1:2]  # Only keep the data byte

    res_img = np.frombuffer(res, dtype=np.uint8)
    res_img = res_img.reshape((IMG_HEIGHT, IMG_WIDTH, 3))

else:
    buff = mat.tobytes()

    mat_gray = np.sum(mat, axis=2) // 3

    sim_img = convolve2d(mat_gray, [[-1, -1, -1], [-1, 8, -1], [-1, -1, -1]], mode="same")

    sim_img[sim_img < 0] = 0
    sim_img[sim_img > 127] = 127
    sim_img = sim_img.astype(np.uint8)

    dev.write(b'\xff')
    for i in tqdm(range(IMG_HEIGHT)):
        dev.write(buff[i * IMG_WIDTH * 3:(i + 1) * IMG_WIDTH * 3])

    dev.write(b'\xf1')
    dev.flush()

    if test_n == 4 or test_n == 5:
        exit()
    else:
        res = dev.read(IMG_HEIGHT * IMG_WIDTH + 2)

    res_img = np.frombuffer(res[1:-1], dtype=np.uint8)
    res_img = res_img.reshape((IMG_HEIGHT, IMG_WIDTH))

if (test_n == 6 and (res_img == mat).all()) or (res_img == sim_img).all():
    print("Image Match!")
else:
    print("Image Mismatch!")

im = Image.fromarray(res_img)
im.show()
