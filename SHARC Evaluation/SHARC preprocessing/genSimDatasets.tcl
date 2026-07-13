# -------------------- Paths --------------------
set folder Test
#set folder set15
set basePath "C:/Users/gamage_a/Documents/CM_Curves/SimOutput/WMGL241/NoCollision_20260511/$folder"
cd $basePath

file mkdir "$basePath/textFiles4STDAN"
file mkdir "$basePath/textFiles4CSLSTM"
file mkdir "$basePath/textFiles4MMnTP"

# -------------------- Shuffle erg files --------------------
set resFiles [glob *.erg]

proc shuffle {list} {
    set n [llength $list]
    for {set i 0} {$i < $n} {incr i} {
        set j [expr {int(rand() * $n)}]
        set temp [lindex $list $j]
        set list [lreplace $list $j $j [lindex $list $i]]
        set list [lreplace $list $i $i $temp]
    }
    return $list
}

set files [shuffle $resFiles]

# -------------------- Channels --------------------
set channels {
Time Car.Fr1.tx Car.Fr1.ty Car.Fr1.vx Car.Fr1.vy Car.v Car.Fr1.ax Car.Fr1.ay Car.ax
Car.Road.Lane.Act.LaneId Car.Road.sRoad RdVector.y

Traffic.T01.tx Traffic.T01.ty Traffic.T01.v_0.x Traffic.T01.v_0.y Traffic.T01.LatVel Traffic.T01.LongVel
Traffic.T01.a_0.x Traffic.T01.a_0.y Traffic.T01.LongAcc Traffic.T01.Lane.Act.LaneId Traffic.T01.sRoad

Traffic.T02.tx Traffic.T02.ty Traffic.T02.v_0.x Traffic.T02.v_0.y Traffic.T02.LatVel Traffic.T02.LongVel
Traffic.T02.a_0.x Traffic.T02.a_0.y Traffic.T02.LongAcc Traffic.T02.Lane.Act.LaneId Traffic.T02.sRoad

Traffic.T03.tx Traffic.T03.ty Traffic.T03.v_0.x Traffic.T03.v_0.y Traffic.T03.LatVel Traffic.T03.LongVel
Traffic.T03.a_0.x Traffic.T03.a_0.y Traffic.T03.LongAcc Traffic.T03.Lane.Act.LaneId Traffic.T03.sRoad

Traffic.T04.tx Traffic.T04.ty Traffic.T04.v_0.x Traffic.T04.v_0.y Traffic.T04.LatVel Traffic.T04.LongVel
Traffic.T04.a_0.x Traffic.T04.a_0.y Traffic.T04.LongAcc Traffic.T04.Lane.Act.LaneId Traffic.T04.sRoad

Traffic.T05.tx Traffic.T05.ty Traffic.T05.v_0.x Traffic.T05.v_0.y Traffic.T05.LatVel Traffic.T05.LongVel
Traffic.T05.a_0.x Traffic.T05.a_0.y Traffic.T05.LongAcc Traffic.T05.Lane.Act.LaneId Traffic.T05.sRoad

Traffic.T06.tx Traffic.T06.ty Traffic.T06.v_0.x Traffic.T06.v_0.y Traffic.T06.LatVel Traffic.T06.LongVel
Traffic.T06.a_0.x Traffic.T06.a_0.y Traffic.T06.LongAcc Traffic.T06.Lane.Act.LaneId Traffic.T06.sRoad

Traffic.T00.tx Traffic.T00.ty Traffic.T00.v_0.x Traffic.T00.v_0.y Traffic.T00.LatVel Traffic.T00.LongVel
Traffic.T00.a_0.x Traffic.T00.a_0.y Traffic.T00.LongAcc Traffic.T00.Lane.Act.LaneId Traffic.T00.sRoad
}

# -------------------- Vehicle IDs --------------------

set carIDs {}
for {set i 1} {$i <= [expr {[llength $files] * 8}]} {incr i} {
    lappend carIDs $i
}

## Create a unique vehicleID list starting from 3367 based on number of .erg files 
#set carIDs {}
## There are 3366 vehicle IDs recorded in NGSIM Dataset.
#set startID 3367 
#set totalCars [expr {[llength $files]*8}]
#for {set i 0} {$i < $totalCars} {incr i} {
#    lappend carIDs [expr {$startID + $i}]
#}


#-------------- Process for creating a random number--------------
proc myRand {min max} {
    	set range [expr {$max - $min + 1}]
    	return [expr {$min + int(rand() * $range)}]
}

# -------------------- Main Loop --------------------
set cnt 0
#set p 1
set f 0

# to be removed
set n 8 


set idx 0
set tcl_precision 4

# Separate numbering for LLC and RLC files
set llcCount 0
set rlcCount 0

foreach erg_file $files {
    incr idx

    # Determine LC direction from filename
    set lowerName [string tolower $erg_file]

    if {[string match "*lc_left*" $lowerName]} {

        incr llcCount
        set trackName "Sim_LLC_$llcCount.txt"

    } elseif {[string match "*lc_right*" $lowerName]} {

        incr rlcCount
        set trackName "Sim_RLC_$rlcCount.txt"

    } else {

        puts "WARNING: Cannot determine LC direction for $erg_file"
        continue
    }


    # Generate datasetID between 1-6 randomly
    #set datID [myRand 1 6]
    set datID [myRand 1 5]

    ImportResFile $erg_file $channels Results

    # Time is already a TCL list
    set tmStp $Results(Time)

    # Scenario duration
    set scnDur [llength $tmStp]

    # ---------- MMnTP ----------
    #set outfile [open "$basePath/textFiles4MMnTP/[file rootname $erg_file]_results.txt" w]
    #set outfile [open "$basePath/textFiles4MMnTP/Sim_track_$idx.txt" w]
    set outfile [open "$basePath/textFiles4MMnTP/$trackName" w]


    # Vehicle list (same ordering across all models)
    set vehList {
    Car.Fr1
    Traffic.T01
    Traffic.T02
    Traffic.T03
    Traffic.T04
    Traffic.T05
    Traffic.T06
    Traffic.T00
    }

    # ---------------- Vehicle geometry lookup ----------------
    array set vehDim {
    Car.Fr1   "4.28 1.82"
    Traffic.T00 "4.12 1.80"
    Traffic.T01 "4.74 1.82"
    Traffic.T02 "5.19 1.98"
    Traffic.T03 "11.89 2.55"
    Traffic.T04 "4.69 1.85"
    Traffic.T05 "11.50 2.48"
    Traffic.T06 "4.90 1.88"
    }
    
    set classVal 2

    for {set i 1} {$i < [llength $tmStp]} {incr i} {

    	#set timeVal [expr {$i + 1 + $cnt}]
	set timeVal [expr {$i + $cnt}]

    	for {set v 0} {$v < 8} {incr v} {

        	set veh [lindex $vehList $v]

        	# ---------------- carID ----------------
        	set carID [lindex $carIDs [expr {$f*8 + $v}]]

        	# ---------------- dimensions ----------------
        	set dim $vehDim($veh)
        	set vehLen [lindex $dim 0]
        	set vehWid [lindex $dim 1]

        	# ---------------- base signals ----------------
        	set tyKey "$veh.ty"
        	set txKey "$veh.tx"
        	
        	set ty     [lindex $Results($tyKey) $i]
        	set tx     [lindex $Results($txKey) $i]
        		
		# ---------------- dynamic signals ----------------
        	if {$v == 0} {

    		set latVel  [lindex $Results(Car.Fr1.vx) $i]
    		set longVel [lindex $Results(Car.Fr1.vy) $i]

    		set ax      [lindex $Results(Car.Fr1.ax) $i]
   		set ay      [lindex $Results(Car.Fr1.ay) $i]

    		set lane    [lindex $Results(Car.Road.Lane.Act.LaneId) $i]
    		set sRoad   [lindex $Results(Car.Road.sRoad) $i]

		} else {

    		set latVel  [lindex $Results($veh.LatVel) $i]
    		set longVel [lindex $Results($veh.LongVel) $i]

    		set ax      [lindex $Results($veh.a_0.x) $i]
    		set ay      [lindex $Results($veh.a_0.y) $i]

    		set lane    [lindex $Results($veh.Lane.Act.LaneId) $i]
    		set sRoad   [lindex $Results($veh.sRoad) $i]
		}

		set ry [lindex $Results(RdVector.y) $i]

        	# ---------------- output ----------------
        	#puts $outfile "$datID\t$carID\t$timeVal\t$ty\t$tx\t$vehLen\t$vehWid\t$classVal\t$latVel\t$longVel\t$acc\t$lane\t[lindex $Results(RdVector.y) $i]"
		puts $outfile "$carID\t$timeVal\t$ty\t$tx\t$vehLen\t$vehWid\t$classVal\t$latVel\t$longVel\t$ay\t$ax\t$lane\t$sRoad\t$ry"
    	}
    }

    close $outfile

    # ---------- STDAN ----------
    #set outfile [open "$basePath/textFiles4STDAN/[file rootname $erg_file]_results.txt" w]
    #set outfile [open "$basePath/textFiles4STDAN/Sim_track_$idx.txt" w]
    set outfile [open "$basePath/textFiles4STDAN/$trackName" w]

    # Vehicle prefixes in order
    set vehList {
    Car.Fr1
    Traffic.T01
    Traffic.T02
    Traffic.T03
    Traffic.T04
    Traffic.T05
    Traffic.T06
    Traffic.T00
    }

    # Fixed lane/type value used in original script
    set classVal 2

    for {set i 1} {$i < [llength $tmStp]} {incr i} {
	# set timeVal [expr {$i + 1 + $cnt}]
	set timeVal [expr {$i + $cnt}]

	for {set v 0} {$v < 8} {incr v} {

		set veh [lindex $vehList $v]

        	# ---------------- carID ----------------
        	set carID [lindex $carIDs [expr {$f*8 + $v}]]

       		# common fields
        	set ty   [lindex $Results($veh.ty) $i]
        	set tx   [lindex $Results($veh.tx) $i]

        	# velocity/acc (different naming for ego vs traffic)
        	if {$v == 0} {
            		set vel [lindex $Results(Car.v) $i]
            		set acc [lindex $Results(Car.ax) $i]
            		set lane [expr {[lindex $Results(Car.Road.Lane.Act.LaneId) $i]+1}]
        	} else {
            		set vel [lindex $Results($veh.LongVel) $i]
            		set acc [lindex $Results($veh.LongAcc) $i]
           		set lane [expr {[lindex $Results($veh.Lane.Act.LaneId) $i]+1}]
       		}

		# write line
		puts $outfile "$datID\t$carID\t$timeVal\t$ty\t$tx\t$vel\t$acc\t$lane\t$classVal\t[lindex $Results(RdVector.y) $i]"
    	}
    }
    close $outfile

    # ---------- CSLSTM ----------
    #set outfile [open "$basePath/textFiles4CSLSTM/[file rootname $erg_file]_results.txt" w]
    #set outfile [open "$basePath/textFiles4CSLSTM/Sim_track_$idx.txt" w]
    set outfile [open "$basePath/textFiles4CSLSTM/$trackName" w]

    # Vehicle prefixes in order
    set vehList {
    Car.Fr1
    Traffic.T01
    Traffic.T02
    Traffic.T03
    Traffic.T04
    Traffic.T05
    Traffic.T06
    Traffic.T00
    }

    for {set i 1} {$i < [llength $tmStp]} {incr i} {
	# set timeVal [expr {$i + 1 + $cnt}]
	set timeVal [expr {$i + $cnt}]

	for {set v 0} {$v < 8} {incr v} {

		set veh [lindex $vehList $v]

        	# ---------------- carID ----------------
        	set carID [lindex $carIDs [expr {$f*8 + $v}]]

		# ---------------- signals ----------------
        	if {$v == 0} {

            		# Ego vehicle (Car.Fr1)
           		set ty   [lindex $Results(Car.Fr1.ty) $i]
           		set tx   [lindex $Results(Car.Fr1.tx) $i]
            		set lane [lindex $Results(Car.Road.Lane.Act.LaneId) $i]
            		set ry   [lindex $Results(RdVector.y) $i]

        	} else {

			# Traffic vehicles
            		set tyKey   "$veh.ty"
            		set txKey   "$veh.tx"
            		set laneKey "$veh.Lane.Act.LaneId"

            		set ty   [lindex $Results($tyKey) $i]
            		set tx   [lindex $Results($txKey) $i]
            		set lane [lindex $Results($laneKey) $i]
            		set ry   [lindex $Results(RdVector.y) $i]
        	}

		# ---------------- output ----------------
        	puts $outfile "$datID\t$carID\t$timeVal\t$ty\t$tx\t$lane\t$ry"
    	}
    }

    close $outfile

    # Update counters
    set cnt [expr {$cnt + $scnDur}]
    array unset Results
    incr f
}

# ---------- Combined dataset generation (parameter style) ----------

set selectedFiles $files
set tcl_precision 4
set cnt 0

# Global erg file counter
set datasetFileIdx 0

# Split into 5 groups
set n [expr {[llength $selectedFiles] / 5}]

# ---------- vehicle ordering (MUST match other models) ----------
set vehList {
    Car.Fr1
    Traffic.T01
    Traffic.T02
    Traffic.T03
    Traffic.T04
    Traffic.T05
    Traffic.T06
    Traffic.T00
}

 # ---------------- Vehicle geometry lookup ----------------
    array set vehDim {
    Car.Fr1   "4.28 1.82"
    Traffic.T00 "4.12 1.80"
    Traffic.T01 "4.74 1.82"
    Traffic.T02 "5.19 1.98"
    Traffic.T03 "11.89 2.55"
    Traffic.T04 "4.69 1.85"
    Traffic.T05 "11.50 2.48"
    Traffic.T06 "4.90 1.88"
    }
    
    set classVal 2

# ---------- create 5 dataset files ----------
for {set p 1} {$p <= 5} {incr p} {

    set subList [lrange $selectedFiles [expr {$n*($p-1)}] [expr {$n*$p - 1}]]
    set outfile [open "simDataset$p.txt" a+]

    for {set f 0} {$f < [llength $subList]} {incr f} {

        set fname [lindex $subList $f]
        ImportResFile $fname $channels Results

        # ----- time processing -----
        set tmStp $Results(Time)
        for {set k 0} {$k < [llength $tmStp]} {incr k} {
            lset tmStp $k [expr {[lindex $tmStp $k]*100 + 1}]
        }
        #set scnDur [expr {max([join $tmStp ","])}]
	#set scnDur 0
	#foreach t $tmStp {
    	#	if {$t > $scnDur} {
        #		set scnDur $t
    	#	}
	#}
	set scnDur [llength $Results(Time)]

       # ----- vehicle-first loop (correct logging order) -----
       	for {set v 0} {$v < 8} {incr v} {

    		set veh   [lindex $vehList $v]
    		set carID [lindex $carIDs [expr {$datasetFileIdx*8 + $v}]]

    		# ---------------- dimensions ----------------
    		set dim $vehDim($veh)
    		set vehLen [lindex $dim 0]
    		set vehWid [lindex $dim 1]

    		# ----- time loop INSIDE -----
    		for {set i 0} {$i < [llength $tmStp]} {incr i} {

			set timeVal [expr {$i + 1 + $cnt}]

        		if {$v == 0} {
            			set ty   [lindex $Results(Car.Fr1.ty) $i]
            			set tx   [lindex $Results(Car.Fr1.tx) $i]
            			set latVel   [lindex $Results(Car.Fr1.vx) $i]
            			set longVel  [lindex $Results(Car.Fr1.vy) $i]
            			set ax   [lindex $Results(Car.Fr1.ax) $i]
            			set ay   [lindex $Results(Car.Fr1.ay) $i]
            			set lane [lindex $Results(Car.Road.Lane.Act.LaneId) $i]
            			set sRoad [lindex $Results(Car.Road.sRoad) $i]
            			#set ry   [lindex $Results(RdVector.y) $i]
        		} else {
            			set ty   [lindex $Results($veh.ty) $i]
            			set tx   [lindex $Results($veh.tx) $i]
            			set latVel  [lindex $Results($veh.LatVel) $i]
            			set longVel [lindex $Results($veh.LongVel) $i]
            			set ax   [lindex $Results($veh.a_0.x) $i]
            			set ay   [lindex $Results($veh.a_0.y) $i]
            			set lane [lindex $Results($veh.Lane.Act.LaneId) $i]
            			set sRoad [lindex $Results($veh.sRoad) $i]
            			#set ry   [lindex $Results(RdVector.y) $i]
        		}
			set ry   [lindex $Results(RdVector.y) $i]

        		puts $outfile "$carID\t$timeVal\t$ty\t$tx\t$vehLen\t$vehWid\t$classVal\t$latVel\t$longVel\t$ay\t$ax\t$lane\t$sRoad\t$ry"
    		}
	}
        set cnt [expr {$cnt + $scnDur}]
	array unset Results

	# Move to next source erg file
	incr datasetFileIdx
    }

    close $outfile
}