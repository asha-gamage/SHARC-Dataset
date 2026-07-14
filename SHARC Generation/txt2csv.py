from pathlib import Path
import pandas as pd

# Folder containing the text files
folder = Path(r"C:\Users\gamage_a\Documents\CM_Curves\SimOutput\WMGL241\NoCollision_20260511\fullCombined_simDatasets")

# Find all .txt files
txt_files = list(folder.glob("*.txt"))

if not txt_files:
    print("No text files found.")
else:
    print(f"Found {len(txt_files)} text files.\n")

    for txt_file in txt_files:
        try:
            # Automatically detect delimiter (comma, tab, spaces, etc.)
            df = pd.read_csv(
            txt_file,
            delim_whitespace=True,
            header=None
            )

            # Output CSV filename
            csv_file = txt_file.with_suffix(".csv")

            # Save CSV
            df.to_csv(csv_file, index=False)

            print(f"✓ Converted: {txt_file.name} -> {csv_file.name}")

        except Exception as e:
            print(f"✗ Failed to convert {txt_file.name}")
            print(e)

print("\nFinished.")