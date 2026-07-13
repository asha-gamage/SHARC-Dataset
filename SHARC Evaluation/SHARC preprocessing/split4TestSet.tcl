# --------------------------------------------------
# User settings
# --------------------------------------------------
set folder NoCollision_20260511
set sourceFolder "C:/Users/gamage_a/Documents/CM_Curves/SimOutput/WMGL241/$folder"

set folder15 "$sourceFolder/set15"
set folder85 "$sourceFolder/set85"

# --------------------------------------------------
# Create output folders
# --------------------------------------------------
file mkdir $folder15
file mkdir $folder85

# --------------------------------------------------
# Get all .erg files
# --------------------------------------------------
set ergFiles [glob -nocomplain -directory $sourceFolder *.erg]

set totalFiles [llength $ergFiles]

if {$totalFiles == 0} {
    puts "No .erg files found."
    exit
}

puts "Found $totalFiles .erg files"

# --------------------------------------------------
# Shuffle file list (Fisher-Yates)
# --------------------------------------------------
set shuffled $ergFiles

for {set i [expr {$totalFiles - 1}]} {$i > 0} {incr i -1} {

    set j [expr {int(rand()*($i+1))}]

    set temp [lindex $shuffled $i]

    lset shuffled $i [lindex $shuffled $j]
    lset shuffled $j $temp
}

# --------------------------------------------------
# Calculate split sizes
# --------------------------------------------------
set num15 [expr {round($totalFiles * 0.15)}]

puts "15% set size = $num15"
puts "85% set size = [expr {$totalFiles - $num15}]"

# --------------------------------------------------
# Copy files
# --------------------------------------------------
for {set idx 0} {$idx < $totalFiles} {incr idx} {

    set ergFile [lindex $shuffled $idx]

    if {$idx < $num15} {
        set destination $folder15
    } else {
        set destination $folder85
    }

    # Copy .erg
    file copy -force $ergFile $destination

    # Corresponding .erg.info file
    set infoFile "${ergFile}.info"

    if {[file exists $infoFile]} {
        file copy -force $infoFile $destination
    } else {
        puts "Warning: Missing info file for [file tail $ergFile]"
    }
}

puts "Done."
puts "Files copied to:"
puts "  $folder15"
puts "  $folder85"