nagios-plugins
==============

Repository of modified existing Nagios plugins - all changes will be pushed to upstream
Check original location if changes are already accepted!


check_emc_clariion.pl
---------------------
  
Original script: https://www.netways.org/projects/plugins/files

Changes:

 # Changelog:    
 # * Fri Dec 7 2012 Rene Koch <r.koch@ovido.at>    
 # - added storage pool utilization check (including perfdata)    
 # - added exclusion of iSCSI ports    
 # - added exclusion of specific ports    
 # - fixed error count calculation for FC ports    


check_snmp_brocade
------------------
 
Original script: http://exchange.nagios.org/directory/Plugins/Hardware/Network-Gear/Brocade/check_snmp_brocade--2D-monitor-Brocade-fibre-channel-switches/details

Changes:
 
 # - 26 April 2013 Version 3.0.0    
 #    - Added support for SNMPv3 (René Koch)    
 #    - Changed exit code to 3 (UNKNOWN) if input validation fails    
 #    
 # - 06 May 2013 Version 3.1.0   
 #    - Added warning and critical checks (René Koch)


check_snmp_environment.pl
-------------------------
  
Original script: http://exchange.nagios.org/directory/Plugins/Hardware/Network-Gear/Cisco/Check-various-hardware-environmental-sensors/details


Changes:

 # Add performance data output for Cisco switch temperatures    
 # general: Enable use of Nagios ePN (embedded Perl Nagios)    
 # juniper: Hardcoded global box thresholds for mem, temp, CPU    
 # juniper: Field Replaceable Units (FRUs) monitoring    
 # juniper: Alarms counts (Red, Yellow)    


check_usbtlight.pl
------------------
  
Original script: https://www.netways.org/projects/plugins/files

Changes:

 # Modified for HTTPS and clewarecontrol 2.5 support by Rene Koch / ovido gmbh    

