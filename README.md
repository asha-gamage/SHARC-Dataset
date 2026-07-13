# SHARC Dataset

A Large Collection of Synthetic Vehicle Trajectory Data on Highway Curves

## SHARC (Synthetic Highway Automotive Road Curves)

<a href="images/preprocessing_pipeline.png">
  <img src="images/preprocessing_pipeline.png" width="1200">
</a>

# SHARC Dataset

## A Large Collection of Synthetic Vehicle Trajectory Data on Highway Curves

**SHARC (Synthetic Highway Automotive Road Curves)** is a large-scale synthetic ego-centric automotive trajectory dataset developed for research into deep learning-based vehicle trajectory prediction for automated driving applications.

![SHARC Dataset Generation and Evaluation Pipeline](images/preprocessing_pipeline.png)

## Overview

Recent advances in automated driving have led to increasing demand for data-driven trajectory prediction algorithms. However, existing naturalistic driving datasets are often limited by restricted road geometries, limited scenario diversity, and insufficient representation of challenging highway driving conditions such as road curves.

To address these limitations, SHARC provides a large collection of synthetic vehicle trajectories generated under controlled highway driving scenarios with diverse road geometries, including curved highway sections.

To the best of our knowledge, SHARC is the first sufficiently large ego-centric automotive trajectory dataset specifically designed to capture diverse highway road geometries for training and evaluating deep neural network-based trajectory prediction models.

## Dataset Generation

SHARC was generated using **IPG CarMaker**, a high-fidelity vehicle and traffic simulation platform widely used in automotive research and development.

The dataset generation pipeline includes:

- Scenario definition and configuration
- Highway road geometry generation
- Traffic participant modelling
- Ego-vehicle trajectory generation
- Sensor-oriented data extraction
- Data preprocessing and post-processing

The provided repository includes:

- IPG CarMaker scenario definitions
- Scenario configuration files
- Dataset generation scripts
- Data preprocessing utilities
- Evaluation scripts

## Dataset Characteristics

| Characteristic | Description |
|---|---|
| Dataset name | SHARC (Synthetic Highway Automotive Road Curves) |
| Data type | Synthetic ego-centric vehicle trajectory data |
| Simulation environment | IPG CarMaker |
| Driving environment | Multi-lane highways with diverse road geometries |
| Primary scenarios | Highway lane-change manoeuvres |
| Road geometries | Straight and curved highway sections |
| Prediction task | Vehicle trajectory prediction |

## Dataset Statistics

The SHARC simulation dataset contains:

- **6,366 lane-change trajectory files**
- Approximately **25 seconds duration per trajectory**
- Balanced distribution of:
  - Left lane changes (LLC)
  - Right lane changes (RLC)

For benchmarking and comparison, SHARC was also evaluated alongside processed naturalistic trajectory data:

- **NGSIM filtered lane-change dataset**
- **4,784 lane-change trajectories**

## Applications

The SHARC dataset supports research in:

- Deep neural network-based trajectory prediction
- Autonomous driving behaviour modelling
- Sensor configuration optimisation
- Simulation-to-real generalisation studies
- Data-driven automated driving algorithms

The dataset has been evaluated using representative trajectory prediction models including:

- CS-LSTM
- STDAN
- MMnTP

## Repository Structure
