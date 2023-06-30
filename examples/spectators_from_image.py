"""
    Dependencies:
    - requests
    - Pillow (PIL)
    - numpy
"""

import sys
import io

import requests
from PIL import Image
import numpy as np

def main():
    if len(sys.argv) < 2:
        print(f"Usage: python spectators_from_image.py SCALE IMAGE_URL\n\n  SCALE is the ratio game_dist / pixel (destination is a flat rectangle).\n  Image should be black and white: black=spectators, white=none, center of image will be the origin.\n  Copy this file to the Spectators storage directory and run it from there.")
        return
    run_spectators_from_image(*sys.argv)



def run_spectators_from_image(_, scale_str, url, *args):
    scale = float(scale_str)
    print(f"Image URL: {url}, scale: {scale} m/pixel")
    resp = requests.get(url)
    if resp.status_code != 200:
        raise Exception("image download url request did not have status not 200")
    image_bs = resp.content
    print(f"image type: {type(image_bs)}, len: {len(image_bs)}")
    img = Image.open(io.BytesIO(image_bs))
    img_arr = np.array(img)
    img_x, img_z = img.size
    radius_x = img_x * scale
    radius_z = img_z * scale

    spectators = read_export_file()
    nb_specs = len(spectators)
    print(f"Read {nb_specs} spectators")

    log_each = nb_specs // 10

    for i, spec in enumerate(spectators):
        # spec[4:6] are x,y,z coords
        # y
        spec[5] = 0.0
        x, z = pick_random_point(img, radius_x, radius_z, img_arr, img_x, img_z)
        spec[4] = x
        spec[6] = z
        if i % log_each == 0:
            print(f"Progress: {i / nb_specs * 100} %")
    print(f"Saving Import.csv")

    write_import_csv(spectators)

    print(f"Wrote out Import.csv. Done")



def pick_random_point(img, rx: float, rz: float, img_arr: np.array, ix, iz):
    hit = False
    while not hit:
        u = round((ix - 1) * np.random.random())
        v = round((iz - 1) * np.random.random())
        ui = int(u)
        vi = int(v)
        pixel = img_arr[vi][ui]
        r = pixel[0]
        g = pixel[1]
        b = pixel[2]
        hit = ((r + g + b) / 3.) < 0.5
        if hit:
            return (rx * (u / ix * -2. + 1.), rz * (v / iz * -2. + 1.))


def write_import_csv(data: list[list[float]]):
    with open('Import.csv', 'w') as f:
        f.write("\n".join(map(sz_line, data)))

def sz_line(line: list[float]) -> str:
    return ",".join(map(lambda n: f"{n:.6f}", line))

def read_export_file() -> list[list[float]]:
    """
    returns [[qx, qy, qz, qw, px, py, pz]]
    """
    ret: list[list[float]] = []
    with open('Export.csv', 'r') as f:
        for line in f.readlines():
            ret.append(list(map(float, line.split(','))))
    return ret


if __name__ == "__main__":
    main()
