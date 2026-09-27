#!/usr/bin/env python3
"""ComfyUI API クライアント — プロンプト → PNG。標準ライブラリのみ。

  python comfy_generate.py --prompt "..." --out C:\YBJ\パース\a.png [--negative ...] [--steps 25] [--size 1024x576] [--seed 42] [--n 4]

サーバー（start-comfy.ps1）が http://127.0.0.1:8188 で起動している前提。
--n 4 のときは a_1.png … a_4.png（seed を +1 ずつ）。
"""
from __future__ import annotations
import argparse, json, os, random, sys, time, urllib.request, uuid
from pathlib import Path

HOST = os.environ.get("COMFY_HOST", "http://127.0.0.1:8188")
HERE = Path(__file__).resolve().parent


def post(path: str, payload: dict) -> dict:
    req = urllib.request.Request(f"{HOST}{path}", data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def get(path: str, raw: bool = False):
    with urllib.request.urlopen(f"{HOST}{path}", timeout=60) as r:
        return r.read() if raw else json.loads(r.read())


def run_one(wf: dict, out: Path) -> Path:
    cid = uuid.uuid4().hex
    pid = post("/prompt", {"prompt": wf, "client_id": cid})["prompt_id"]
    for _ in range(600):  # 最大 10 分
        hist = get(f"/history/{pid}")
        if pid in hist and hist[pid].get("outputs"):
            for node in hist[pid]["outputs"].values():
                for img in node.get("images", []):
                    q = f"/view?filename={urllib.request.quote(img['filename'])}&subfolder={urllib.request.quote(img.get('subfolder',''))}&type={img.get('type','output')}"
                    out.parent.mkdir(parents=True, exist_ok=True)
                    out.write_bytes(get(q, raw=True))
                    return out
        time.sleep(1)
    raise TimeoutError("生成がタイムアウト")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--prompt", required=True)
    ap.add_argument("--negative", default=None)
    ap.add_argument("--out", required=True)
    ap.add_argument("--steps", type=int, default=25)
    ap.add_argument("--cfg", type=float, default=6.5)
    ap.add_argument("--size", default="1024x576")
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--n", type=int, default=1)
    ap.add_argument("--workflow", default=str(HERE / "workflow_sdxl_t2i.json"))
    ap.add_argument("--ckpt", default=None, help="models/checkpoints 内のファイル名で差し替え")
    a = ap.parse_args()

    try:
        get("/system_stats")
    except Exception as e:  # noqa: BLE001
        print(f"ComfyUI サーバーに繋がりません（{HOST}）。start-comfy.ps1 を起動してください: {e}", file=sys.stderr)
        return 2

    base = json.loads(Path(a.workflow).read_text(encoding="utf-8"))
    w, h = (int(x) for x in a.size.lower().split("x"))
    seed0 = a.seed if a.seed is not None else random.randrange(2**31)
    out = Path(a.out)
    for i in range(a.n):
        wf = json.loads(json.dumps(base))
        wf["6"]["inputs"]["text"] = a.prompt
        if a.negative is not None:
            wf["7"]["inputs"]["text"] = a.negative
        wf["3"]["inputs"].update(seed=seed0 + i, steps=a.steps, cfg=a.cfg)
        wf["5"]["inputs"].update(width=w, height=h)
        if a.ckpt:
            wf["4"]["inputs"]["ckpt_name"] = a.ckpt
        target = out if a.n == 1 else out.with_name(f"{out.stem}_{i+1}{out.suffix}")
        t = time.time()
        p = run_one(wf, target)
        print(f"{p}  seed={seed0 + i}  {time.time() - t:.1f}s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
