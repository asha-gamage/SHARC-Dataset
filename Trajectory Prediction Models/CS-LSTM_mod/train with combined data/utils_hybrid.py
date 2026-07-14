# This version ensures 0,0 for the x, y coordinates for track history (hist) is retained
# for the potential missing track data points potentially due to occlusions etc. This is
# achieved by checking for time frames for which both the x, y coordinates are zero and then
# ensuring the 'hist' is assigned with 0 (not 0 - reference position, i.e. coordinates of
# the target car.

# 'use_maneuvers' is set to 'True'

# 25/05/25 updated to handle if there are multiple matches for [vehTrack[:, 0] == t] in 'getHistory' function 
# in line [stpt = np.maximum(0, np.argwhere(vehTrack[:, 0] == t).item() - self.t_h)] and similar updates to 
# 'getFuture' function and saved as utils_250525.py

from __future__ import print_function, division
from torch.utils.data import Dataset, DataLoader
import scipy.io as scp
import numpy as np
import torch
import h5py
#___________________________________________________________________________________________________________________________

### Dataset class for the NGSIM dataset
class ngsimDataset(Dataset):

    def __init__(self, mat_file, t_h=30, t_f=50, d_s=2, enc_size = 64, grid_size = (13,3)):
        # self.D = scp.loadmat(mat_file)['traj']
        self.h5_file = h5py.File(mat_file_1, 'r')
        # KEEP AS HDF5 HANDLE (NO np.array)
        self.D = self.h5_file['traj']  
        self.T = scp.loadmat(mat_file_2)['combiTracks'] # updated the name
        # self.T = scp.loadmat(mat_file)['tracks']
        self.t_h = t_h  # length of track history
        self.t_f = t_f  # length of predicted trajectory
        self.d_s = d_s  # down sampling rate of all sequences
        self.enc_size = enc_size # size of encoder LSTM
        self.grid_size = grid_size # size of social context grid

    def __len__(self):
        # return len(self.D)
        return self.D.shape[1]

    def __getitem__(self, idx):

        # dsId = self.D[idx, 0].astype(int)
        # vehId = self.D[idx, 1].astype(int)
        # RdAng = self.D[idx, 6] #Added
        # t = self.D[idx, 2]
        # grid = self.D[idx,9:] # Updated to 9 from 8
        
        row = np.array(self.D[:, idx], dtype=np.float32)

        dsId = int(row[0])      # dataset id
        vehId = int(row[1])     # agent id
        RdAng = row[6]          # Added
        t = row[2]              # frame
        grid = row[9:]         # grid id       
        neighbors = []

        # Get track history 'hist' = ndarray, and future track 'fut' = ndarray
        hist = self.getHistory(vehId,t,vehId,dsId,RdAng)
        fut = self.getFuture(vehId,t,dsId,RdAng)

        # Get track histories of all neighbours 'neighbors' = [ndarray,[],ndarray,ndarray]
        for i in grid:
            neighbors.append(self.getHistory(i.astype(int), t,vehId,dsId,RdAng))

        # Maneuvers 'lon_enc' = one-hot vector, 'lat_enc = one-hot vector
        lon_enc = np.zeros([2])        
        # lon_enc[int(self.D[idx, 8] - 1)] = 1 # Updated to 8 from 7
        lon_enc[int(row[8] - 1)] = 1
        lat_enc = np.zeros([3])
        # lat_enc[int(self.D[idx, 7] - 1)] = 1 # Updated to 7 from 6
        lat_enc[int(row[7] - 1)] = 1

        return hist,fut,neighbors,lat_enc,lon_enc

    ## Helper function to get track history
    def getHistory(self,vehId,t,refVehId,dsId,RdAng):
        if vehId == 0:
            return np.empty([0,2])
        else:
            if self.T.shape[1]<=vehId-1:
                return np.empty([0,2])
            refTrack = self.T[dsId-1][refVehId-1].transpose()
            vehTrack = self.T[dsId-1][vehId-1].transpose()
            refPos = refTrack[np.where(refTrack[:, 0] == t)][0, 1:3]
            refPosCon = self.cordConv(refPos[1],refPos[0],RdAng)# added to convert coordinates to the target vehicle frame

            if vehTrack.size==0 or np.argwhere(vehTrack[:, 0] == t).size==0:
                 return np.empty([0,2])
            else:                
                indices = np.argwhere(vehTrack[:, 0] == t)    
                if indices.shape[0] > 1:
                    print(f"Warning: multiple matches found — vehicleID: {vehId}, time: {t}, indices: {indices.flatten().tolist()}")
                first_index = indices[0][0]  # Use only the first match

                stpt = max(0, first_index - self.t_h)
                enpt = first_index + 1
                histOri = vehTrack[stpt:enpt:self.d_s, 1:3]
                            
                # stpt = np.maximum(0, np.argwhere(vehTrack[:, 0] == t).item() - self.t_h)
                # enpt = np.argwhere(vehTrack[:, 0] == t).item() + 1
                # histOri = vehTrack[stpt:enpt:self.d_s,1:3]#-(refPos) #Introduced abs()

                histCon = self.cordConv(histOri[:,1],histOri[:,0],RdAng) # added to convert coordinates to the target vehicle frame
                histCon = np.asarray(histCon).transpose()
                refPosCon = np.asarray(refPosCon)
                hist = np.asarray(histCon)
                # For undetected timeframes (zero coordinates for x, y), set the hist to (0,0).
                # Only if it's been measured, determine the position by deducting the refPos.
                for i in range(len(histCon)):
                    if (histCon[i, 1] == 0) and (histCon[i, 0] == 0):
                        hist[i, :] = 0
                    else:
                        hist[i, :] = histCon[i, :] - refPosCon
                # hist = histCon[:,:] - refPosCon
                hist[:, [0, 1]] = hist[:, [1, 0]]

            if len(hist) < self.t_h//self.d_s + 1:
                return np.empty([0,2])
            return hist

    ## Helper function to get track future
    def getFuture(self, vehId, t,dsId,RdAng):
        vehTrack = self.T[dsId-1][vehId-1].transpose()
        refPos = vehTrack[np.where(vehTrack[:, 0] == t)][0, 1:3]
        refPosCon = self.cordConv(refPos[1], refPos[0], RdAng) # added
        #refPosCon = np.asarray(refPosCon)
        indices = np.argwhere(vehTrack[:, 0] == t)    
        if indices.size == 0:
            print(f"Warning: no match found — vehicleID: {vehId}, time: {t}")
            return np.empty([0, 2])  # or handle as needed
        else:
            if indices.shape[0] > 1:
                print(f"Warning: multiple matches found — vehicleID: {vehId}, time: {t}, indices: {indices.flatten().tolist()}")

            first_index = indices[0][0]

            stpt = first_index + self.d_s
            enpt = min(len(vehTrack), first_index + self.t_f + 1)
                       
        # stpt = np.argwhere(vehTrack[:, 0] == t).item() + self.d_s
        # enpt = np.minimum(len(vehTrack), np.argwhere(vehTrack[:, 0] == t).item() + self.t_f + 1)
            futOri = vehTrack[stpt:enpt:self.d_s, 1:3]  # -(refPos) #Introduced abs()
            futCon = self.cordConv(futOri[:, 1], futOri[:, 0],RdAng)  # added to convert coordinates to the target vehicle frame
            futCon = np.asarray(futCon).transpose()
            fut = futCon[:, :] - (refPosCon)
            fut[:, [0, 1]] = fut[:, [1, 0]]

        return fut

    ## Added Helper function to convert the coordinates
    def cordConv(self, X, Y, ang):
        deltaY = Y - X * np.tan(ang)
        deltaX = deltaY * np.sin(ang)
        xCon = X / np.cos(ang) + deltaX
        yCon = np.cos(ang) * deltaY
        return xCon,yCon

    ## Collate function for dataloader
    def collate_fn(self, samples):

        # Initialize neighbors and neighbors length batches:
        nbr_batch_size = 0
        for _,_,nbrs,_,_ in samples:
            nbr_batch_size += sum([len(nbrs[i])!=0 for i in range(len(nbrs))])
        maxlen = self.t_h//self.d_s + 1
        nbrs_batch = torch.zeros(maxlen,nbr_batch_size,2)


        # Initialize social mask batch:
        pos = [0, 0]
        mask_batch = torch.zeros(len(samples), self.grid_size[1],self.grid_size[0],self.enc_size)
        mask_batch = mask_batch.bool()#byte()


        # Initialize history, history lengths, future, output mask, lateral maneuver and longitudinal maneuver batches:
        hist_batch = torch.zeros(maxlen,len(samples),2)
        fut_batch = torch.zeros(self.t_f//self.d_s,len(samples),2)
        op_mask_batch = torch.zeros(self.t_f//self.d_s,len(samples),2)
        lat_enc_batch = torch.zeros(len(samples),3)
        lon_enc_batch = torch.zeros(len(samples), 2)


        count = 0
        for sampleId,(hist, fut, nbrs, lat_enc, lon_enc) in enumerate(samples):

            # Set up history, future, lateral maneuver and longitudinal maneuver batches:
            hist_batch[0:len(hist),sampleId,0] = torch.from_numpy(hist[:, 0])
            hist_batch[0:len(hist), sampleId, 1] = torch.from_numpy(hist[:, 1])
            fut_batch[0:len(fut), sampleId, 0] = torch.from_numpy(fut[:, 0])
            fut_batch[0:len(fut), sampleId, 1] = torch.from_numpy(fut[:, 1])
            op_mask_batch[0:len(fut),sampleId,:] = 1
            lat_enc_batch[sampleId,:] = torch.from_numpy(lat_enc)
            lon_enc_batch[sampleId, :] = torch.from_numpy(lon_enc)

            # Set up neighbor, neighbor sequence length, and mask batches:
            for id,nbr in enumerate(nbrs):
                if len(nbr)!=0:
                    nbrs_batch[0:len(nbr),count,0] = torch.from_numpy(nbr[:, 0])
                    nbrs_batch[0:len(nbr), count, 1] = torch.from_numpy(nbr[:, 1])
                    pos[0] = id % self.grid_size[0]
                    pos[1] = id // self.grid_size[0]
                    mask_batch[sampleId,pos[1],pos[0],:] = torch.ones(self.enc_size).bool()#.byte()
                    count+=1

        return hist_batch, nbrs_batch, mask_batch, lat_enc_batch, lon_enc_batch, fut_batch, op_mask_batch

#________________________________________________________________________________________________________________________________________

## Custom activation for output layer (Graves, 2015)
def outputActivation(x):
    muX = x[:,:,0:1]
    muY = x[:,:,1:2]
    sigX = x[:,:,2:3]
    sigY = x[:,:,3:4]
    rho = x[:,:,4:5]
    sigX = torch.exp(sigX)
    sigY = torch.exp(sigY)
    rho = torch.tanh(rho)
    out = torch.cat([muX, muY, sigX, sigY, rho],dim=2)
    return out

## Batchwise NLL loss, uses mask for variable output lengths
def maskedNLL(y_pred, y_gt, mask):
    acc = torch.zeros_like(mask)
    muX = y_pred[:,:,0]
    muY = y_pred[:,:,1]
    sigX = y_pred[:,:,2]
    sigY = y_pred[:,:,3]
    rho = y_pred[:,:,4]
    ohr = torch.pow(1-torch.pow(rho,2),-0.5)
    x = y_gt[:,:, 0]
    y = y_gt[:,:, 1]
    # If we represent likelihood in feet^(-1):
    # out = 0.5*torch.pow(ohr, 2)*(torch.pow(sigX, 2)*torch.pow(x-muX, 2) + torch.pow(sigY, 2)*torch.pow(y-muY, 2) - 2*rho*torch.pow(sigX, 1)*torch.pow(sigY, 1)*(x-muX)*(y-muY)) - torch.log(sigX*sigY*ohr) + 1.8379
    # If we represent likelihood in m^(-1):
    out = 0.5 * torch.pow(ohr, 2) * (torch.pow(sigX, 2) * torch.pow(x - muX, 2) + torch.pow(sigY, 2) * torch.pow(y - muY, 2) - 2 * rho * torch.pow(sigX, 1) * torch.pow(sigY, 1) * (x - muX) * (y - muY)) - torch.log(sigX * sigY * ohr) + 1.8379 - 0.5160
    acc[:,:,0] = out
    acc[:,:,1] = out
    acc = acc*mask
    lossVal = torch.sum(acc)/torch.sum(mask)
    return lossVal

## NLL for sequence, outputs sequence of NLL values for each time-step, uses mask for variable output lengths, used for evaluation
def maskedNLLTest(fut_pred, lat_pred, lon_pred, fut, op_mask, num_lat_classes=3, num_lon_classes = 2,use_maneuvers = True, avg_along_time = False):
    if use_maneuvers:
        acc = torch.zeros(op_mask.shape[0],op_mask.shape[1],num_lon_classes*num_lat_classes).cuda()
        count = 0
        for k in range(num_lon_classes):
            for l in range(num_lat_classes):
                wts = lat_pred[:,l]*lon_pred[:,k]
                wts = wts.repeat(len(fut_pred[0]),1)
                y_pred = fut_pred[k*num_lat_classes + l]
                y_gt = fut
                muX = y_pred[:, :, 0]
                muY = y_pred[:, :, 1]
                sigX = y_pred[:, :, 2]
                sigY = y_pred[:, :, 3]
                rho = y_pred[:, :, 4]
                ohr = torch.pow(1 - torch.pow(rho, 2), -0.5)
                x = y_gt[:, :, 0]
                y = y_gt[:, :, 1]
                # If we represent likelihood in feet^(-1):
                # out = -(0.5*torch.pow(ohr, 2)*(torch.pow(sigX, 2)*torch.pow(x-muX, 2) + 0.5*torch.pow(sigY, 2)*torch.pow(y-muY, 2) - rho*torch.pow(sigX, 1)*torch.pow(sigY, 1)*(x-muX)*(y-muY)) - torch.log(sigX*sigY*ohr) + 1.8379)
                # If we represent likelihood in m^(-1):
                out = -(0.5 * torch.pow(ohr, 2) * (torch.pow(sigX, 2) * torch.pow(x - muX, 2) + torch.pow(sigY, 2) * torch.pow(y - muY, 2) - 2 * rho * torch.pow(sigX, 1) * torch.pow(sigY, 1) * (x - muX) * (y - muY)) - torch.log(sigX * sigY * ohr) + 1.8379 - 0.5160)
                acc[:, :, count] =  out + torch.log(wts)
                count+=1
        acc = -logsumexp(acc, dim = 2)
        acc = acc * op_mask[:,:,0]

        # ## Helper function for log sum exp calculation:
        # def logsumexp(inputs, dim=None, keepdim=False):
        #     if dim is None:
        #         inputs = inputs.view(-1)  # view(-1) operation flattens the tensor.
        #         dim = 0
        #     s, _ = torch.max(inputs, dim=dim, keepdim=True)
        #     outputs = s + (inputs - s).exp().sum(dim=dim, keepdim=True).log()
        #     if not keepdim:
        #         outputs = outputs.squeeze(dim)
        #     return outputs

        if avg_along_time:
            lossVal = torch.sum(acc) / torch.sum(op_mask[:, :, 0])
            return lossVal
        else:
            lossVal = torch.sum(acc,dim=1)
            counts = torch.sum(op_mask[:,:,0],dim=1)
            return lossVal,counts
    else:
        acc = torch.zeros(op_mask.shape[0], op_mask.shape[1], 1).cuda()
        y_pred = fut_pred
        y_gt = fut
        print('y_pred = ', y_pred)
        muX = y_pred[:, :, 0]
        muY = y_pred[:, :, 1]
        sigX = y_pred[:, :, 2]
        sigY = y_pred[:, :, 3]
        rho = y_pred[:, :, 4]
        ohr = torch.pow(1 - torch.pow(rho, 2), -0.5)
        x = y_gt[:, :, 0]
        y = y_gt[:, :, 1]
        # If we represent likelihood in feet^(-1):
        # out = 0.5*torch.pow(ohr, 2)*(torch.pow(sigX, 2)*torch.pow(x-muX, 2) + torch.pow(sigY, 2)*torch.pow(y-muY, 2) - 2 * rho*torch.pow(sigX, 1)*torch.pow(sigY, 1)*(x-muX)*(y-muY)) - torch.log(sigX*sigY*ohr) + 1.8379
        # If we represent likelihood in m^(-1):
        out = 0.5 * torch.pow(ohr, 2) * (torch.pow(sigX, 2) * torch.pow(x - muX, 2) + torch.pow(sigY, 2) * torch.pow(y - muY, 2) - 2 * rho * torch.pow(sigX, 1) * torch.pow(sigY, 1) * (x - muX) * (y - muY)) - torch.log(sigX * sigY * ohr) + 1.8379 - 0.5160
        acc[:, :, 0] = out
        acc = acc * op_mask[:, :, 0:1]
        if avg_along_time:
            lossVal = torch.sum(acc[:, :, 0]) / torch.sum(op_mask[:, :, 0])
            return lossVal
        else:
            lossVal = torch.sum(acc[:,:,0], dim=1)
            counts = torch.sum(op_mask[:, :, 0], dim=1)
            return lossVal,counts

## Batchwise MSE loss, uses mask for variable output lengths
def maskedMSE(y_pred, y_gt, mask):
    acc = torch.zeros_like(mask)
    muX = y_pred[:,:,0]
    muY = y_pred[:,:,1]
    x = y_gt[:,:, 0]
    y = y_gt[:,:, 1]
    out = torch.pow(x-muX, 2) + torch.pow(y-muY, 2)
    acc[:,:,0] = out
    acc[:,:,1] = out
    acc = acc*mask
    lossVal = torch.sum(acc)/torch.sum(mask)
    return lossVal

## MSE loss for complete sequence, outputs a sequence of MSE values, uses mask for variable output lengths, used for evaluation
def maskedMSETest(y_pred, y_gt, mask):
    acc = torch.zeros_like(mask)
    muX = y_pred[:, :, 0]
    muY = y_pred[:, :, 1]
    x = y_gt[:, :, 0]
    y = y_gt[:, :, 1]
    out = torch.pow(x - muX, 2) + torch.pow(y - muY, 2)
    acc[:, :, 0] = out
    acc[:, :, 1] = out
    acc = acc * mask
    lossVal = torch.sum(acc[:,:,0],dim=1)
    counts = torch.sum(mask[:,:,0],dim=1)
    return lossVal, counts

## Helper function for log sum exp calculation:
def logsumexp(inputs, dim=None, keepdim=False):
    if dim is None:
        inputs = inputs.view(-1) # view(-1) operation flattens the tensor.
        dim = 0
    s, _ = torch.max(inputs, dim=dim, keepdim=True) # Returns a namedtuple (values, indices) where values is the maximum value of each row of the input tensor in the given dimension dim. And indices is the index location of each maximum value found (argmax).
                                                    # If keepdim is True, the output tensors are of the same size as input except in the dimension dim where they are of size 1. Otherwise, dim is squeezed (see torch.squeeze()), resulting in the output tensors having 1 fewer dimension than input.
    outputs = s + (inputs - s).exp().sum(dim=dim, keepdim=True).log()
    if not keepdim:
        outputs = outputs.squeeze(dim)
    return outputs
