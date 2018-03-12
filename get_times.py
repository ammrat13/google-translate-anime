#!/usr/bin/python3
################################################################################
# get_times.py
# By: Ammar Ratnani
#
# This program serves as a subroutine to gtr_anime.sh. It will take in an srt 
# file as a parameter, and output to stdout the time intervals in that file 
# in seconds with each interval on one line with a comma between the start and 
# end times.
################################################################################


import sys
import re as regex

# Subroutine that takes in an srt formatted time and outputs the time in seconds
def calc_secs(tft):
	ts = regex.split("[:,]", tft)
	return int(ts[0])*60*60 + int(ts[1])*60 + int(ts[2]) + int(ts[3])/100

# Open the files
with open(sys.argv[1], "r") as inp:
	for inp_line in inp:
		# If the line specifies the time as Start --> End
		if " --> " in inp_line:
			trs = inp_line.split(" --> ")
			print( ("{:.2f},{:.2f}".format(calc_secs(trs[0]), calc_secs(trs[1]))) )
	inp.close()