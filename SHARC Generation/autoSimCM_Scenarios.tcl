# -------------------- DATE-BASED RESULT FOLDERS--------------------
set runDate [clock format [clock seconds] -format "%Y%m%d"]

set baseOut "SimOutput/wmgl241"
set noColDir "$baseOut/NoCollision_$runDate"
set colDir   "$baseOut/Collision_$runDate"

file mkdir $noColDir
file mkdir $colDir

# -------------------- GLOBAL SETTINGS --------------------
set pi 3.1415926
set egoVel 72
NamedValue set EgoVel $egoVel

cd "C:/Users/gamage_a/Documents/CM_Curves/Data/TestRun"
set Scne_lst [glob Scenario*]
cd "C:/Users/gamage_a/Documents/CM_Curves"

OpenSLog datasetCreation.log
QuantSubscribe {Sensor.Collision.Vhcl.Fr1.Count nHitTraffic}

# ---- Add output quantities ONCE (critical fix) ----
	set quants {Time RdVector.y Car.Yaw Car.Fr1.tx Car.Fr1.ty Car.Fr1.vx Car.Fr1.vy Car.v Car.Fr1.ax Car.Fr1.ay Car.ax Car.Road.Lane.Act.LaneId Car.Road.sRoad\ 
	Traffic.T00.tx Traffic.T00.ty Traffic.T00.v_0.x Traffic.T00.v_0.y Traffic.T00.LatVel Traffic.T00.LongVel Traffic.T00.a_0.x Traffic.T00.a_0.y Traffic.T00.LongAcc Traffic.T00.Lane.Act.LaneId Traffic.T00.sRoad\
	Traffic.T01.tx Traffic.T01.ty Traffic.T01.v_0.x Traffic.T01.v_0.y Traffic.T01.LatVel Traffic.T01.LongVel Traffic.T01.a_0.x Traffic.T01.a_0.y Traffic.T01.LongAcc Traffic.T01.Lane.Act.LaneId Traffic.T01.sRoad\
	Traffic.T02.tx Traffic.T02.ty Traffic.T02.v_0.x Traffic.T02.v_0.y Traffic.T02.LatVel Traffic.T02.LongVel Traffic.T02.a_0.x Traffic.T02.a_0.y Traffic.T02.LongAcc Traffic.T02.Lane.Act.LaneId Traffic.T02.sRoad\
	Traffic.T03.tx Traffic.T03.ty Traffic.T03.v_0.x Traffic.T03.v_0.y Traffic.T03.LatVel Traffic.T03.LongVel Traffic.T03.a_0.x Traffic.T03.a_0.y Traffic.T03.LongAcc Traffic.T03.Lane.Act.LaneId Traffic.T03.sRoad\
	Traffic.T04.tx Traffic.T04.ty Traffic.T04.v_0.x Traffic.T04.v_0.y Traffic.T04.LatVel Traffic.T04.LongVel Traffic.T04.a_0.x Traffic.T04.a_0.y Traffic.T04.LongAcc Traffic.T04.Lane.Act.LaneId Traffic.T04.sRoad\
	Traffic.T05.tx Traffic.T05.ty Traffic.T05.v_0.x Traffic.T05.v_0.y Traffic.T05.LatVel Traffic.T05.LongVel Traffic.T05.a_0.x Traffic.T05.a_0.y Traffic.T05.LongAcc Traffic.T05.Lane.Act.LaneId Traffic.T05.sRoad\
	Traffic.T06.tx Traffic.T06.ty Traffic.T06.v_0.x Traffic.T06.v_0.y Traffic.T06.LatVel Traffic.T06.LongVel Traffic.T06.a_0.x Traffic.T06.a_0.y Traffic.T06.LongAcc Traffic.T06.Lane.Act.LaneId Traffic.T06.sRoad\
	}
OutQuantsAdd $quants

# -------------------- DOE VALUES --------------------
set radiusList {80 120 160 200}
set angleList  {60 100 140}
set velList    {78 86 94}
set pctList    {0.15 0.40 0.65 0.90}
set durList    {4 7}

set hdmList {
    {0.4 0.8 0.5 0.2 0.7 0.5 0.7}
    {0.5 0.5 0.5 0.5 0.5 0.5 0.5}
    {0.6 0.2 0.5 0.8 0.3 0.5 0.3}
}
set hdmCat {"Defensive" "Normal" "Aggressive"}

# -------------------- MAIN LOOP --------------------
foreach n $Scne_lst {

    LoadTestRun $n

    # Initial run to activate traffic quantities
    SaveMode collect
    SetSimTimeAcc 999999
    StartSim
    WaitForStatus idle
    SaveMode save

    set StrLen [expr {
        [lindex [IFileRead Road Link.0.Seg.0.Param] 0] +
        [lindex [IFileRead Road Link.0.Seg.2.Param] 0]
    }]

    foreach turnType {TurnRight TurnLeft} {

        IFileModify Road Link.0.Seg.1.Type $turnType
        IFileFlush

        foreach rad $radiusList {
            NamedValue set Rad $rad

            foreach ang $angleList {
                NamedValue set Ang $ang

                set rdLen [expr {(2*$pi*$rad/360.0)*$ang + $StrLen}]

                foreach vel $velList {
                    NamedValue set LonV $vel

                    foreach pct $pctList {
                        set pos [expr {$rdLen * $pct}]
                        NamedValue set Pos $pos

                        foreach dur $durList {
                            NamedValue set Dur $dur

                            foreach i $hdmCat j $hdmList {

                                IFileModify TestRun Traffic.0.AutoDrv.Long.Kind HDM
                                IFileModify TestRun Traffic.0.AutoDrv.Long.HDM.ActivateHDM 1
                                IFileModify TestRun Traffic.0.AutoDrv.Long.HDM.Param $j
                                IFileFlush

                                # -------- RUN SIMULATION --------
                                StartSim
                                WaitForStatus running
                                WaitForStatus idle

                                set hdmParam [IFileRead TestRun Traffic.0.AutoDrv.Long.HDM.Param]

                                # -------- LOG SETTINGS (YOUR ORIGINAL BLOCK) --------
                                Log file+ "\nTestRun: $n"
                                Log file+ "Turn of the road curve: $turnType"
                                Log file+ "Radius of the road curve: $rad"
                                Log file+ "Angle of the road curve: $ang"
                                Log file+ "Relative Lon velocity: [expr {$vel - $egoVel}] km/h"
                                Log file+ "Lane change starting at $pos m into the drive"
                                Log file+ "Duration of LC maneuver: $dur sec"
                                Log file+ "HDM Setting: $i HDM Params: $hdmParam"

                                # -------- COLLISION BASED SAVING --------
                                if {$Qu(Sensor.Collision.Vhcl.Fr1.Count)>0 || $Qu(nHitTraffic)>0} {
    					SetResultFName "$colDir/%t_%T%?_s"
    					Log file+ "Collision occurred!!!"
				} else {
    					SetResultFName "$noColDir/%t_%T%?_s"
				}
				SaveStart
                            }
                        }
                    }
                }
            }
        }
    }
}

CloseSLog
OutQuantsRestoreDefs