from PIL import Image

def pad_image(input_path, output_path, padding_ratio=0.3):
    img = Image.open(input_path).convert("RGBA")
    w, h = img.size
    pad_w = int(w * padding_ratio)
    pad_h = int(h * padding_ratio)
    
    new_w = w + 2 * pad_w
    new_h = h + 2 * pad_h
    
    # Create new image with transparent background
    new_img = Image.new("RGBA", (new_w, new_h), (255, 255, 255, 0))
    new_img.paste(img, (pad_w, pad_h))
    new_img.save(output_path)

pad_image("assets/logo.png", "assets/icon.png", 0.4)
