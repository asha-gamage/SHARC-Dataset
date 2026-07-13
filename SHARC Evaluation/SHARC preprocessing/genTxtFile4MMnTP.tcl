# -----------------------------
# SETTINGS
# -----------------------------
set folder ""

set basePath "C:/Users/gamage_a/Documents/CM_Curves/matlabScripts/set85/textFiles4MMnTP"
set folderPath [file join $basePath $folder]

set safeFolder [string map {" " "_" "%" "pct"} $folder]

# -----------------------------
# GET INPUT FILES
# -----------------------------
set txtFiles [lsort [glob -nocomplain [file join $folderPath *.txt]]]

set nFiles [llength $txtFiles]

puts "Files found: $nFiles"

if {$nFiles == 0} {
    error "No txt files found."
}

# -----------------------------
# SPLIT FILES INTO 3 GROUPS
# -----------------------------
set idx1_end [expr {int(ceil($nFiles / 3.0)) - 1}]
set idx2_end [expr {int(ceil(2.0 * $nFiles / 3.0)) - 1}]

set group1 [lrange $txtFiles 0 $idx1_end]
set group2 [lrange $txtFiles [expr {$idx1_end + 1}] $idx2_end]
set group3 [lrange $txtFiles [expr {$idx2_end + 1}] end]

set groups [list $group1 $group2 $group3]

# -----------------------------
# PROCESS EACH GROUP
# -----------------------------
for {set g 0} {$g < 3} {incr g} {

    set fileGroup [lindex $groups $g]

    puts ""
    puts "Processing Group [expr {$g+1}]"
    puts "Files in group: [llength $fileGroup]"

    # vehicle(vehID) = list of {time row}
    catch {unset vehicle}
    array set vehicle {}

    # -------------------------
    # READ FILES
    # -------------------------
    foreach file $fileGroup {

        puts "Reading [file tail $file]"

        set fid [open $file r]

        while {[gets $fid line] >= 0} {

            set line [string trim $line]
            if {$line eq ""} continue

            set fields [regexp -all -inline {\S+} $line]

            if {[llength $fields] < 2} continue

            set vid  [expr {int([lindex $fields 0])}]
            set time [expr {double([lindex $fields 1])}]

            lappend vehicle($vid) [list $time $line]
        }

        close $fid
    }

    puts "Vehicles found: [array size vehicle]"

    # -------------------------
    # OUTPUT FILE
    # -------------------------
    set partNum [expr {$g + 1}]
    set outputFile \
        [file join $folderPath "${safeFolder}_MMnTP_Input_Part${partNum}.txt"]

    set fout [open $outputFile w]

    set vehIDs [lsort -integer [array names vehicle]]

    foreach vid $vehIDs {

        set rows $vehicle($vid)

        set rows [lsort -real -index 0 $rows]

        foreach r $rows {
            puts $fout [lindex $r 1]
        }
    }

    close $fout

    puts "DONE -> $outputFile"
}

puts ""
puts "All groups completed."