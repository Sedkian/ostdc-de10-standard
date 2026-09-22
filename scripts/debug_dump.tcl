# System Console Automation Script
# ==============================================================================

# Locate and claim the JTAG-to-Avalon Master Bridge
set service_paths [get_service_paths master]

if {[llength $service_paths] == 0} {
    puts "ERROR: No JTAG-to-Avalon Master bridge found. Ensure JTAG IP is included in Qsys."
    return
}

set claim_path [lindex $service_paths 0]
set master [claim_service master $claim_path ""]

puts "Connected to JTAG Master: $claim_path"

# Base address assigned to debug_core_avalon in Qsys/Platform Designer
set BASE_ADDR 0x00000000

# Register Offsets (32-bit word aligned)
set REG_CONTROL $BASE_ADDR
set REG_TRIGGER [expr {$BASE_ADDR + 0x4}]
set REG_STATUS  [expr {$BASE_ADDR + 0x0}]
set REG_BUFFER  [expr {$BASE_ADDR + 0x8}]
set REG_DEPTH   [expr {$BASE_ADDR + 0xC}]

# Reset Core
puts "Issuing Soft Reset..."
master_write_32 $master $REG_CONTROL 0x02

# Configure Trigger Condition (Set trigger pattern)
set trigger_val 0x000000FF
puts "Setting Trigger Pattern: $trigger_val"
master_write_32 $master $REG_TRIGGER $trigger_val

# Arm the Capture Engine (Bit 0 = 1)
puts "Arming Core..."
master_write_32 $master $REG_CONTROL 0x01

# Poll Status Register until Triggered/Full
puts "Waiting for Trigger event..."
set timeout 200
set status 0

while {($status & 0x6) == 0 && $timeout > 0} {
    set status [master_read_32 $master $REG_STATUS 1]
    after 100
    incr timeout -1
}

if {$timeout == 0} {
    puts "TIMEOUT: Core did not trigger. Current Status Register: $status"
} else {
    puts "Capture Complete! Final Status Register: $status"
}

# Read Trace Buffer Depth
set depth [master_read_32 $master $REG_DEPTH 1]
puts "Reading $depth samples from M10K Trace RAM..."

# Dump Trace Data to File
set fp [open "trace_dump.csv" w]
puts $fp "Sample_Index,Data_Hex"

for {set i 0} {$i < $depth} {incr i} {
    set sample [master_read_32 $master $REG_BUFFER 1]
    puts $fp "$i,$sample"
}

close $fp
puts "Trace dump saved successfully to trace_dump.csv"

# Release the JTAG service
close_service master $master