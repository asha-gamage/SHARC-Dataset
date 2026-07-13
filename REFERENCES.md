# References



This file provides references for the datasets, simulation environments, and benchmark models used in the development and evaluation of the SHARC dataset.



---



# 1. Simulation Environment



The SHARC dataset was generated using IPG CarMaker, a high-fidelity vehicle and traffic simulation platform.



Please cite:



```bibtex

@misc{IPG_carmaker,

author       = {{IPG Automotive GmbH}},

title        = {IPG CarMaker: Virtual Test Driving for Vehicle Development},

howpublished = {\\url{https://www.ipg-automotive.com/en/products-solutions/software/carmaker/}}

}

```



---



# 2. Benchmark Trajectory Prediction Models



SHARC evaluation experiments utilise established deep learning-based trajectory prediction models. Users of these implementations should cite the original publications.


---



## 2.1 Convolutional Social LSTM (CS-LSTM)


Please cite the original CS-LSTM publication:

```bibtex

@article{CS_LSTM,

author  = {Deo, Nachiket and Trivedi, Mohan M.},

title   = {Convolutional Social Pooling for Vehicle Trajectory Prediction},

journal = {IEEE Transactions on Intelligent Vehicles},

volume  = {3},

number  = {1},

pages   = {24--34},

year    = {2018},

publisher = {IEEE}

}

```



---



## 2.2 Spatio-Temporal Dynamic Attention Network (STDAN)



Please cite the original STDAN publication:



```bibtex

@article{STDAN,

author = {Chen, Xiaobo and Zhang, Huanjia and Zhao, Feng and Hu, Yu and Tan, Chenkai and Yang, Jian},

title = {Intention-aware vehicle trajectory prediction based on spatial-temporal dynamic attention network for internet of vehicles},

journal = {IEEE Transactions on Intelligent Transportation Systems},

volume = {23},

number = {10},

pages = {19471-19483},

ISSN = {1524-9050},

year = {2022},

type = {Journal Article}

}

```



---

## 2.3 Multi-Modal Neural Trajectory Prediction (MMnTP)



Please cite the original MMnTP publication:



```bibtex

@article{MMnTP,

title={Multimodal manoeuvre and trajectory prediction for automated driving on highways using transformer networks},

author={Mozaffari, Sajjad and Sormoli, Mreza Alipour and Koufos, Konstantinos and Dianati, Mehrdad},

journal={IEEE Robotics and Automation Letters},

year={2023},

publisher={IEEE}

}

```


---



# 3. Naturalistic Driving Dataset



SHARC benchmarking includes comparison against the Next Generation Simulation (NGSIM) naturalistic driving dataset.



Please cite:



```bibtex

@techreport{ngsim,

author      = {{Federal Highway Administration}},

title       = {Next Generation Simulation (NGSIM) Vehicle Trajectories and Supporting Data},

institution = {U.S. Department of Transportation},

year        = {2006}

}

```



Dataset access:



https://data.transportation.gov/



---





