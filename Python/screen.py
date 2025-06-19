from PIL import Image

WIDTH, HEIGHT = 640, 480
img = Image.new("RGB", (WIDTH, HEIGHT), "black")
pixels = img.load()

with open("screen_pixels.txt") as f:
    for line in f:
        row, col, r, g, b = line.strip().split()
        row = int(row)
        col = int(col)
        # 4位转8位
        r = int(r, 16) * 17
        g = int(g, 16) * 17
        b = int(b, 16) * 17
        if 0 <= col < WIDTH and 0 <= row < HEIGHT:
            pixels[col, row] = (r, g, b)

img.save("screen_pixels.png")
print("图片已保存为 screen_output.png")