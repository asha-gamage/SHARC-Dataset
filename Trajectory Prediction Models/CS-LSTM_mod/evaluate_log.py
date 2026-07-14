from __future__ import print_function
import torch
from model import highwayNet
from utils_250525 import ngsimDataset,maskedNLL,maskedMSETest,maskedNLLTest
from torch.utils.data import DataLoader
import time
import os
from datetime import datetime
import numpy as np


## Network Arguments
args = {}
args['use_cuda'] = True
args['encoder_size'] = 64
args['decoder_size'] = 128
args['in_length'] = 16
args['out_length'] = 25
args['grid_size'] = (13,3)
args['soc_conv_depth'] = 64
args['conv_3x1_depth'] = 16
args['dyn_embedding_size'] = 32
args['input_embedding_size'] = 32
args['num_lat_classes'] = 3
args['num_lon_classes'] = 2
args['use_maneuvers'] = True
args['train_flag'] = False


# Evaluation metric:
metric = 'rmse'  #or nll


# Initialize network
net = highwayNet(args)
model_path = 'trained_models/cslstm_sim_140526.tar'
net.load_state_dict(torch.load(model_path))
if args['use_cuda']:
    net = net.cuda()

tsSet = ngsimDataset('data/CS-LSTM ngsimTest/ngsimTestSet.mat')
# tsDataloader = DataLoader(tsSet,batch_size=128,shuffle=True,num_workers=8,collate_fn=tsSet.collate_fn)
tsDataloader = DataLoader(tsSet,batch_size=128,shuffle=True,num_workers=2,collate_fn=tsSet.collate_fn)

lossVals = torch.zeros(25).cuda()
counts = torch.zeros(25).cuda()


for i, data in enumerate(tsDataloader):
    st_time = time.time()
    hist, nbrs, mask, lat_enc, lon_enc, fut, op_mask = data

    # Initialize Variables
    if args['use_cuda']:
        hist = hist.cuda()
        nbrs = nbrs.cuda()
        mask = mask.cuda()
        lat_enc = lat_enc.cuda()
        lon_enc = lon_enc.cuda()
        fut = fut.cuda()
        op_mask = op_mask.cuda()

    if metric == 'nll':
        # Forward pass
        if args['use_maneuvers']:
            fut_pred, lat_pred, lon_pred = net(hist, nbrs, mask, lat_enc, lon_enc)
            l,c = maskedNLLTest(fut_pred, lat_pred, lon_pred, fut, op_mask)
        else:
            fut_pred = net(hist, nbrs, mask, lat_enc, lon_enc)
            l, c = maskedNLLTest(fut_pred, 0, 0, fut, op_mask,use_maneuvers=False)
    else:
        # Forward pass
        if args['use_maneuvers']:
            fut_pred, lat_pred, lon_pred = net(hist, nbrs, mask, lat_enc, lon_enc)
            fut_pred_max = torch.zeros_like(fut_pred[0])
            for k in range(lat_pred.shape[0]):
                lat_man = torch.argmax(lat_pred[k, :]).detach()
                lon_man = torch.argmax(lon_pred[k, :]).detach()
                indx = lon_man*3 + lat_man
                fut_pred_max[:,k,:] = fut_pred[indx][:,k,:]
            l, c = maskedMSETest(fut_pred_max, fut, op_mask)
        else:
            fut_pred = net(hist, nbrs, mask, lat_enc, lon_enc)
            l, c = maskedMSETest(fut_pred, fut, op_mask)


    lossVals +=l.detach()
    counts += c.detach()

if metric == 'nll':
    result = lossVals / counts
    print(result)

    save_dict = {"metric": "nll", "nll_curve": result.detach().cpu().numpy()}
else:
    rmse_curve = torch.pow(lossVals / counts, 0.5) * 0.3048 # Calculate RMSE and convert from feet to meters
    print(rmse_curve)

    save_dict = {"metric": "rmse", "rmse_curve": rmse_curve.detach().cpu().numpy()}

# Save file
base_name = os.path.basename(model_path)
name_no_ext = os.path.splitext(base_name)[0]

# split into parts
parts = name_no_ext.split('_')                        # ['cslstm', 'combi', '200426']
model_type = parts[0].upper()                          # CSLSTM
variant = parts[1]                                   # combi
date_str = datetime.now().strftime("%Y-%m-%d")  
save_filename = f"{model_type}_{variant}_{date_str}_kpis.pt"

results_dir = "results"
os.makedirs(results_dir, exist_ok=True)

save_path = os.path.join(results_dir, save_filename)

torch.save(save_dict, save_path)

print(f"KPI saved to: {save_path}")
