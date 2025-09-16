import base64, json, requests

with open("CdLS.jpg","rb") as f:
    img_b64 = base64.b64encode(f.read()).decode()

auth = ("bh25","gestaltmatcher")
base = "http://127.0.0.1:5001"

# predict
r = requests.post(f"{base}/predict", json={"img": img_b64}, auth=auth)
print("predict:", r.status_code, r.json())

# crop (write to file)
r = requests.post(f"{base}/crop", json={"img": img_b64}, auth=auth)
crop_b64 = r.json()["crop"]
with open("cropped.png","wb") as f:
    f.write(base64.b64decode(crop_b64))
print("saved cropped.png")

# encode
r = requests.post(f"{base}/encode", json={"img": img_b64}, auth=auth)
print("encode keys:", list(r.json().keys()))
