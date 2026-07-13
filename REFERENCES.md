\# References



This file provides references for the datasets, simulation environments, and benchmark models used in the development and evaluation of the SHARC dataset.



\---



\# 1. Simulation Environment



The SHARC dataset was generated using IPG CarMaker, a high-fidelity vehicle and traffic simulation platform.



Please cite:



```bibtex

@misc{ipg\_carmaker,

&#x20; author       = {{IPG Automotive GmbH}},

&#x20; title        = {IPG CarMaker: Virtual Test Driving for Vehicle Development},

&#x20; howpublished = {\\url{https://www.ipg-automotive.com/en/products-solutions/software/carmaker/}}

}

```



\---



\# 2. Benchmark Trajectory Prediction Models



SHARC evaluation experiments utilise established deep learning-based trajectory prediction models. Users of these implementations should cite the original publications.



\---



\## 2.1 Convolutional Social LSTM (CS-LSTM)



```bibtex

@article{CS\_LSTM,

&#x20; author  = {Deo, Nachiket and Trivedi, Mohan M.},

&#x20; title   = {Convolutional Social Pooling for Vehicle Trajectory Prediction},

&#x20; journal = {IEEE Transactions on Intelligent Vehicles},

&#x20; volume  = {3},

&#x20; number  = {1},

&#x20; pages   = {24--34},

&#x20; year    = {2018},

&#x20; publisher = {IEEE}

}

```



\---



\## 2.2 Spatio-Temporal Dynamic Attention Network (STDAN)



Please cite the original STDAN publication:



```bibtex

@article{STDAN,

&#x20;  author = {Chen, Xiaobo and Zhang, Huanjia and Zhao, Feng and Hu, Yu and Tan, Chenkai and Yang, Jian},

&#x20;  title = {Intention-aware vehicle trajectory prediction based on spatial-temporal dynamic attention network for internet of vehicles},

&#x20;  journal = {IEEE Transactions on Intelligent Transportation Systems},

&#x20;  volume = {23},

&#x20;  number = {10},

&#x20;  pages = {19471-19483},

&#x20;  ISSN = {1524-9050},

&#x20;  year = {2022},

&#x20;  type = {Journal Article}

}

\## 2.3 Multi-Modal Neural Trajectory Prediction (MMnTP)



Please cite the original MMnTP publication:



```bibtex

@article{MMnTP,

&#x20; title={Multimodal manoeuvre and trajectory prediction for automated driving on highways using transformer networks},

&#x20; author={Mozaffari, Sajjad and Sormoli, Mreza Alipour and Koufos, Konstantinos and Dianati, Mehrdad},

&#x20; journal={IEEE Robotics and Automation Letters},

&#x20; year={2023},

&#x20; publisher={IEEE}



\---



\# 3. Naturalistic Driving Dataset



SHARC benchmarking includes comparison against the Next Generation Simulation (NGSIM) naturalistic driving dataset.



Please cite:



```bibtex

@techreport{ngsim,

&#x20; author      = {{Federal Highway Administration}},

&#x20; title       = {Next Generation Simulation (NGSIM) Vehicle Trajectories and Supporting Data},

&#x20; institution = {U.S. Department of Transportation},

&#x20; year        = {2006}

}

```



Dataset access:



https://data.transportation.gov/



\---





