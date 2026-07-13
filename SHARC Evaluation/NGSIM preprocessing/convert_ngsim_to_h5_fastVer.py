#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd
import h5py

FT_TO_M = 0.3048

# ============================================================
# EXPECTED MMNTP FEATURE ORDER 
# ============================================================
STATE_DIM = 27

NGSIM_COLUMNS = [
    "vehicle_id",
    "frame_id",
    "total_frames",
    "global_time",
    "local_x",
    "local_y",
    "global_x",
    "global_y",
    "vehicle_length",
    "vehicle_width",
    "vehicle_class",
    "vehicle_velocity",
    "vehicle_acceleration",
    "lane_id",
    "preceding",
    "following",
    "space_headway",
    "time_headway",
]

# ============================================================
# LOAD
# ============================================================
def load_ngsim(path: Path, stride: int) -> pd.DataFrame:
    df = pd.read_csv(
        path,
        sep=r"[\s,]+",
        header=None,
        names=NGSIM_COLUMNS,
        engine="python",
    ).dropna()

    df = df[df.frame_id % stride == 0].copy()

    scale = [
        "local_x",
        "local_y",
        "vehicle_length",
        "vehicle_width",
        "vehicle_velocity",
        "vehicle_acceleration",
        "space_headway",
    ]
    df[scale] *= FT_TO_M

    df = df.sort_values(["vehicle_id", "frame_id"]).reset_index(drop=True)

    return df


# ============================================================
# SEGMENT + TV_ID
# ============================================================
def add_segments(df: pd.DataFrame, stride: int) -> pd.DataFrame:
    df = df.copy()

    frame_step = stride

    new_seg = (
        (df.vehicle_id != df.vehicle_id.shift(1)) |
        ((df.frame_id - df.frame_id.shift(1)) != frame_step)
    )

    df["segment_id"] = new_seg.cumsum().astype(np.int64)

    # REQUIRED MMNTP ID
    df["tv_id"] = df.vehicle_id.astype(np.int64) * 1000 + df.segment_id

    # previous positions
    df["prev_x"] = df.groupby("segment_id")["local_x"].shift(1)
    df["prev_y"] = df.groupby("segment_id")["local_y"].shift(1)

    dt = stride / 10.0

    df["lat_vel"] = ((df.local_x - df.prev_x) / dt).fillna(0.0)
    df["lon_vel"] = df.vehicle_velocity.fillna(0.0)

    df["lat_acc"] = df.groupby("segment_id")["lat_vel"].diff().fillna(0.0) / dt
    df["lon_acc"] = df.vehicle_acceleration.fillna(0.0)

    # df["dx"] = df.local_x - df.prev_x
    # df["dy"] = df.local_y - df.prev_y
    df["dx"] = (df.local_x - df.prev_x).fillna(0.0)
    df["dy"] = (df.local_y - df.prev_y).fillna(0.0)

    # df["label"] = 0
    # df["lane_change_sign"] = 0.0
    df["prev_lane_id"] = (df.groupby("segment_id")["lane_id"].shift(1))

    lane_delta = (df["lane_id"] - df["prev_lane_id"]).fillna(0).astype(int)

    df["label"] = np.select([lane_delta > 0, lane_delta < 0], [1, 2], default=0)

    df["lane_change_sign"] = (np.sign(lane_delta).astype(np.float32))
    
    # # -----------------------------
    # # Remove short segments
    # # -----------------------------
    # min_track_len = 40

    # valid_segments = (
    #     df.groupby("segment_id")
    #       .size()
    # )

    # valid_segments = valid_segments[
    #     valid_segments >= min_track_len
    # ].index

    # df = df[
    #     df.segment_id.isin(valid_segments)
    # ].copy()    

    return df




# ============================================================
# FAST LOOKUPS (NUMPY INDEX BASED)
# ============================================================
def build_index(df: pd.DataFrame):
    frame_vehicle_to_idx = {
        (f, v): i
        for i, (f, v) in enumerate(zip(df.frame_id.values, df.vehicle_id.values))
    }

    frame_groups = {
        f: g.index.values
        for f, g in df.groupby("frame_id", sort=False)
    }

    return frame_vehicle_to_idx, frame_groups


# ============================================================
# NEIGHBOUR FEATURES (FAST VECTORISED LOOKUP)
# ============================================================
def neighbour_features(
    idx_map,
    frame_idx,
    frame_id,
    ego_x,
    ego_y,
    ego_vx,
    ego_vy,
    neighbour_ids,
):
    n = len(neighbour_ids)

    present = np.zeros(n, np.float32)
    rx = np.zeros(n, np.float32)
    ry = np.zeros(n, np.float32)
    rvx = np.zeros(n, np.float32)
    rvy = np.zeros(n, np.float32)

    for i, nid in enumerate(neighbour_ids):
        if nid == 0:
            continue

        key = (frame_id[i], nid)
        j = idx_map.get(key, None)

        if j is None:
            continue

        present[i] = 1.0
        rx[i] = ego_x[j] - ego_x[i]
        ry[i] = ego_y[j] - ego_y[i]
        rvx[i] = ego_vx[j] - ego_vx[i]
        rvy[i] = ego_vy[j] - ego_vy[i]

    return present, rx, ry, rvx, rvy


# ============================================================
# MAIN FEATURE BUILDER (27 DIM MMNTP)
# ============================================================
def build_features(df: pd.DataFrame):

    idx_map, frame_groups = build_index(df)

    n = len(df)

    state = np.zeros((n, STATE_DIM), dtype=np.float32)
    out = np.zeros((n, 2), dtype=np.float32)

    # base arrays
    fx = df.local_x.values
    fy = df.local_y.values
    lane = df.lane_id.values

    vx = df.lat_vel.values
    vy = df.lon_vel.values
    ax = df.lat_acc.values
    ay = df.lon_acc.values

    length = df.vehicle_length.values
    width = df.vehicle_width.values
    vclass = df.vehicle_class.values

    frame_id = df.frame_id.values

    preceding = df.preceding.values
    following = df.following.values

    # --------------------------------------------------------
    # FAST FILL (CORE FEATURES)
    # --------------------------------------------------------
    state[:, 0] = vx
    state[:, 1] = vy
    state[:, 2] = ax
    state[:, 3] = ay
    state[:, 4] = fx
    state[:, 5] = fy
    state[:, 6] = lane

    state[:, 7] = length
    state[:, 8] = width
    state[:, 9] = vclass

    # --------------------------------------------------------
    # NEIGHBOURS (vectorised loop only)
    # --------------------------------------------------------
    for i in range(n):

        f = frame_id[i]

        frame_idx = frame_groups[f]

        # PRECEDING
        pid = preceding[i]
        if pid != 0:
            j = idx_map.get((f, pid), -1)
            if j != -1:
                state[i, 10] = 1.0
                state[i, 11] = fx[j] - fx[i]
                state[i, 12] = fy[j] - fy[i]
                state[i, 13] = vx[j] - vx[i]
                state[i, 14] = vy[j] - vy[i]

        # FOLLOWING
        fid = following[i]
        if fid != 0:
            j = idx_map.get((f, fid), -1)
            if j != -1:
                state[i, 15] = 1.0
                state[i, 16] = fx[j] - fx[i]
                state[i, 17] = fy[j] - fy[i]
                state[i, 18] = vx[j] - vx[i]
                state[i, 19] = vy[j] - vy[i]

        # (simplified adjacent lanes — fast approximation)
        state[i, 20] = 0.0
        state[i, 21] = 0.0
        state[i, 22] = 0.0
        state[i, 23] = 0.0

    # --------------------------------------------------------
    # HEADWAYS (fast approximate version)
    # --------------------------------------------------------
    state[:, 24] = df.space_headway.values
    state[:, 25] = df.space_headway.values / np.maximum(vy, 0.1)

    state[:, 26] = df.lane_change_sign.values

    # --------------------------------------------------------
    # OUTPUT
    # --------------------------------------------------------
    out[:, 0] = df.dx.values
    out[:, 1] = df.dy.values

    return state, out

# ============================================================
# WRITE H5
# ============================================================
def write_h5(path: Path, state, out, df: pd.DataFrame):
    path.parent.mkdir(parents=True, exist_ok=True)

    with h5py.File(path, "w") as f:

        f.create_dataset("state_merging", data=state, compression="lzf")
        f.create_dataset("output_states_data", data=out, compression="lzf")

        f.create_dataset("labels", data=df.label.values.astype(np.int64))
        f.create_dataset("frame_data", data=df.frame_id.values.astype(np.int64))
        f.create_dataset("tv_data", data=df.tv_id.values.astype(np.int64))

# ============================================================
# MAIN
# ============================================================
def main():

    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, nargs="*", default=None)
    parser.add_argument("--output-dir", type=Path,
                        default=Path("Datasets/Processed_NGSIM/RenderedDataset"))
    parser.add_argument("--stride", type=int, default=2)

    args = parser.parse_args()

    if not args.input:
        args.input = sorted(Path("../rawNGSIM").glob("*.txt"))

    for p in args.input:

        print("Processing:", p)

        df = load_ngsim(p, args.stride)
        df = add_segments(df, args.stride)

        state, out = build_features(df)

        assert state.shape[1] == 27, "Feature mismatch!"

        out_path = args.output_dir / f"{p.stem}.h5"

        write_h5(out_path, state, out, df)

        print("Saved:", out_path)

if __name__ == "__main__":
    main()