#!/usr/bin/env python3
"""Convert raw CM trajectory text files into TrajPred HDF5 files.
This script creates the minimum schema needed by the MMnTP config:

    state_merging, output_states_data, labels, frame_data, tv_data

Feature columns are documented in STATE_MERGING_COLUMNS below. 
"""

from __future__ import annotations

import argparse
from pathlib import Path

import h5py
import numpy as np
import pandas as pd


FT_TO_M = 0.3048
STATE_MERGING_COLUMNS = [
    "lat_vel",
    "lon_vel",
    "lat_acc",
    "lon_acc",
    "local_x",
    "local_y",
    "lane_id",
    "vehicle_length",
    "vehicle_width",
    "vehicle_class",
    "preceding_present",
    "preceding_rel_x",
    "preceding_rel_y",
    "preceding_rel_vx",
    "preceding_rel_vy",
    "following_present",
    "following_rel_x",
    "following_rel_y",
    "following_rel_vx",
    "following_rel_vy",
    "left_front_rel_y",
    "left_back_rel_y",
    "right_front_rel_y",
    "right_back_rel_y",
    "space_headway",
    "time_headway",
    "lane_change_sign",
]

CM_COLUMNS = [
    "vehicle_id",
    "frame_id",
    "local_x",
    "local_y",
    "vehicle_length",
    "vehicle_width",
    "vehicle_class",
    "lat_velocity",
    "lon_velocity",
    "lat_accel",
    "lon_accel",
    "lane_id",
    "travel_distance",
    "road_angle",
]

def read_carMaker(path: Path) -> pd.DataFrame:
    df = pd.read_csv(
        path,
        sep=r"[\s,]+",
        header=None,
        names=CM_COLUMNS,
        engine="python",
    )
    df = df.dropna(how="all")
    if df.shape[1] != len(CM_COLUMNS):
        raise ValueError(f"Expected {len(CM_COLUMNS)} CM columns in {path}")
    return df


def prepare_tracks(df: pd.DataFrame, frame_stride: int) -> pd.DataFrame:
    df = df.copy()
    min_frame = int(df["frame_id"].min())
    df = df[(df["frame_id"] - min_frame) % frame_stride == 0].copy()

    df = df.sort_values(["vehicle_id", "frame_id"]).reset_index(drop=True)
    frame_step = int(frame_stride)
    new_segment = (
        (df["vehicle_id"] != df["vehicle_id"].shift(1))
        | ((df["frame_id"] - df["frame_id"].shift(1)) != frame_step)
    )
    df["segment_id"] = new_segment.cumsum().astype(np.int64)
    df["tv_id"] = df["vehicle_id"].astype(np.int64) * 1000 + df["segment_id"]

    dt = frame_stride / 10.0
    df["prev_local_x"] = df.groupby("segment_id")["local_x"].shift(1)
    df["prev_local_y"] = df.groupby("segment_id")["local_y"].shift(1)
    df["prev_lane_id"] = df.groupby("segment_id")["lane_id"].shift(1)
    # df["lat_vel"] = ((df["local_x"] - df["prev_local_x"]) / dt).fillna(0.0)
    df["lat_vel"] = df["lat_velocity"].fillna(0.0)
    df["lon_vel"] = df["lon_velocity"].fillna(0.0)
    df["lat_acc"] = df.groupby("segment_id")["lat_vel"].diff().fillna(0.0) / dt
    df["lon_acc"] = df["lon_accel"].fillna(0.0)
    lane_delta = (df["lane_id"] - df["prev_lane_id"]).fillna(0).astype(int)
    df["label"] = np.select([lane_delta > 0, lane_delta < 0], [1, 2], default=0)
    df["lane_change_sign"] = np.sign(lane_delta).astype(float)
    df["dx"] = (df["local_x"] - df["prev_local_x"]).fillna(0.0)
    df["dy"] = (df["local_y"] - df["prev_local_y"]).fillna(0.0)    
    return df


def row_lookup(df: pd.DataFrame) -> dict[tuple[int, int], pd.Series]:
    return {
        (int(row.frame_id), int(row.vehicle_id)): row
        for row in df.itertuples(index=False)
    }


def add_direct_neighbor_features(
    row: pd.Series, lookup: dict[tuple[int, int], pd.Series], neighbor_id: int
) -> list[float]:
    # neighbor_id = int(row[neighbor_col])
    neighbor = lookup.get((int(row["frame_id"]), neighbor_id))
    if neighbor_id == 0 or neighbor is None:
        return [0.0, 0.0, 0.0, 0.0, 0.0]
    return [
        1.0,
        float(neighbor.local_x - row["local_x"]),
        float(neighbor.local_y - row["local_y"]),
        float(neighbor.lat_vel - row["lat_vel"]),
        float(neighbor.lon_vel - row["lon_vel"]),
    ]

def adjacent_lane_features(
    frame_df: pd.DataFrame,
    row: pd.Series,
) -> tuple[list[float], int, int]:

    lane = int(row["lane_id"])
    y = float(row["local_y"])
    ego_id = int(row["vehicle_id"])

    values = []

    for adj_lane in (lane - 1, lane + 1):
        candidates = frame_df[frame_df["lane_id"] == adj_lane]

        ahead = candidates[candidates["local_y"] > y]
        behind = candidates[candidates["local_y"] < y]

        front_rel_y = (
            float((ahead["local_y"] - y).min()) if not ahead.empty else 0.0)
        back_rel_y = (
            float((behind["local_y"] - y).max()) if not behind.empty else 0.0)

        values.extend([front_rel_y, back_rel_y])

    same_lane = frame_df[
        (frame_df["lane_id"] == lane) & (frame_df["vehicle_id"] != ego_id)]

    ahead_same = same_lane[same_lane["local_y"] > y]
    behind_same = same_lane[same_lane["local_y"] < y]

    # Closest vehicle ahead
    if not ahead_same.empty:
        idx = (ahead_same["local_y"] - y).idxmin()
        preceding_id = int(ahead_same.loc[idx, "vehicle_id"])
    else:
        preceding_id = 0

    # Closest vehicle behind
    if not behind_same.empty:
        idx = (behind_same["local_y"] - y).idxmax()
        following_id = int(behind_same.loc[idx, "vehicle_id"])
    else:
        following_id = 0

    return values, preceding_id, following_id

def compute_all_neighbors(df: pd.DataFrame):
    frames = {f: g for f, g in df.groupby("frame_id")}
    n = len(df)

    adj_features = [None] * n
    preceding_ids = np.zeros(n, dtype=np.int64)
    following_ids = np.zeros(n, dtype=np.int64)

    for i, row in df.iterrows():
        adj, pid, fid = adjacent_lane_features(
            frames[int(row["frame_id"])], row
        )
        adj_features[i] = adj
        preceding_ids[i] = pid
        following_ids[i] = fid

    return adj_features, preceding_ids, following_ids

def compute_headway_features(df: pd.DataFrame, preceding_ids: np.ndarray):
    n = len(df)
    space_headway = np.zeros(n, dtype=np.float32)
    time_headway = np.zeros(n, dtype=np.float32)

    df_indexed = df.set_index(["frame_id", "vehicle_id"])

    for i in range(n):
        prec_id = int(preceding_ids[i])
        if prec_id == 0:
            continue

        frame = int(df.iloc[i]["frame_id"])
        ego_x = float(df.iloc[i]["local_x"])
        ego_len = float(df.iloc[i]["vehicle_length"])
        ego_vel = float(df.iloc[i]["lon_vel"])

        if (frame, prec_id) not in df_indexed.index:
            continue

        prec = df_indexed.loc[(frame, prec_id)]
        prec_x = float(prec["local_x"])
        prec_len = float(prec["vehicle_length"])

        sh = (prec_x - prec_len / 2.0) - (ego_x + ego_len / 2.0)

        space_headway[i] = sh
        time_headway[i] = sh / ego_vel if ego_vel > 0 else 0.0

    return space_headway, time_headway

def build_arrays(df: pd.DataFrame, min_track_len: int) -> dict[str, np.ndarray]:
    lookup = row_lookup(df)

    # ---- Compute neighbors ONCE ----
    adj_features, preceding_ids, following_ids = compute_all_neighbors(df)

    # ---- Compute headways ONCE ----
    space_headway, time_headway = compute_headway_features(df, preceding_ids)

    state_rows = []
    output_rows = []
    label_rows = []
    frame_rows = []
    tv_rows = []

    for i, row in df.iterrows():
        seg_id = row["segment_id"]

        # Skip short segments
        if len(df[df["segment_id"] == seg_id]) < min_track_len:
            continue

        preceding = add_direct_neighbor_features(
            row, lookup, preceding_ids[i])
        following = add_direct_neighbor_features(
            row, lookup, following_ids[i])

        features = [
            float(row["lat_vel"]),
            float(row["lon_vel"]),
            float(row["lat_acc"]),
            float(row["lon_acc"]),
            float(row["local_x"]),
            float(row["local_y"]),
            float(row["lane_id"]),
            float(row["vehicle_length"]),
            float(row["vehicle_width"]),
            float(row["vehicle_class"]),
            *preceding,
            *following,
            *adj_features[i],
            float(space_headway[i]),
            float(time_headway[i]),
            float(row["lane_change_sign"]),
        ]

        state_rows.append(features)
        output_rows.append([float(row["dx"]), float(row["dy"])])
        label_rows.append(int(row["label"]))
        frame_rows.append(int(row["frame_id"]))
        tv_rows.append(int(row["tv_id"]))

    if not state_rows:
        raise ValueError("No valid CM tracks remained after filtering")

    return {
        "state_merging": np.asarray(state_rows, dtype=np.float32),
        "output_states_data": np.asarray(output_rows, dtype=np.float32),
        "labels": np.asarray(label_rows, dtype=np.int64),
        "frame_data": np.asarray(frame_rows, dtype=np.int64),
        "tv_data": np.asarray(tv_rows, dtype=np.int64),
    }

def write_h5(path: Path, arrays: dict[str, np.ndarray]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with h5py.File(path, "w") as h5:
        for key, value in arrays.items():
            h5.create_dataset(key, data=value)
        h5.attrs["state_merging_columns"] = ",".join(STATE_MERGING_COLUMNS)
        h5.attrs["source"] = "scripts/convert_ngsim_to_h5.py"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        type=Path,
        nargs="*",        
        default=None,
        # default=Path("CMdata/trainDataset2.txt"),
        # default=Path("rawNGSIM/trajectories-0750am-0805am.txt"),
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("Datasets/Processed_Sim/RenderedDataset"),
        # default=Path("Datasets/Processed_NGSIM/RenderedDataset"),
    )
    parser.add_argument("--file-id", type=int, default=1)
    parser.add_argument("--frame-stride", type=int, default=2)
    parser.add_argument("--min-in-seq-len", type=int, default=15)
    parser.add_argument("--tgt-seq-len", type=int, default=25)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if not args.input:
        args.input = sorted(Path("../simCM").glob("*.txt"))
        print("No --input provided. Using default files:")
        for f in args.input:
            print("  ", f)

    min_track_len = args.min_in_seq_len + args.tgt_seq_len
    
    # df = prepare_tracks(read_carMaker(args.input), args.frame_stride)
    # arrays = build_arrays(df, min_track_len=min_track_len)
    # output_path = args.output_dir / f"{args.file_id:02d}.h5"
    # write_h5(output_path, arrays)
    
    # for file_id, input_path in enumerate(args.input, start=args.file_id):
    #     print(f"\nProcessing {input_path} → file_id {file_id:02d}")

    #     df = prepare_tracks(read_carMaker(input_path), args.frame_stride)
    #     arrays = build_arrays(df, min_track_len=min_track_len)
                
    #     output_path = args.output_dir / f"{file_id:02d}.h5"
    #     write_h5(output_path, arrays)
    
    #     print(f"Wrote {output_path}")
    #     for key, value in arrays.items():
    #         print(f"{key}: {value.shape} {value.dtype}")
    
    for file_id, input_path in enumerate(args.input, start=args.file_id):
        print(f"\nProcessing {input_path}")

        df = prepare_tracks(read_carMaker(input_path), args.frame_stride)
        arrays = build_arrays(df, min_track_len=min_track_len)

        output_path = args.output_dir / f"{input_path.stem}.h5"

        write_h5(output_path, arrays)

        print(f"Wrote {output_path}")
        for key, value in arrays.items():
            print(f"{key}: {value.shape} {value.dtype}")

if __name__ == "__main__":
    main()
